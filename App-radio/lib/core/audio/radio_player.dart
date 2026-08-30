import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

/// URL del stream en vivo de Radio Doliv (Zeno.FM), tomada de la página web
/// oficial (`RADIODOLIV_PAGINA/script.js` -> `STREAM_URL`).
const String kRadioStreamUrl = 'https://stream.zeno.fm/vrfurwfubkhtv';

/// `true` solo si `JustAudioBackground.init()` terminó bien en `main.dart`.
/// Cuando falla (por ejemplo, `audio_service` no puede registrar su servicio
/// en ciertas versiones de Android), la reproducción NO debe usar el tag
/// `MediaItem`: `just_audio_background` no está interceptando el player y ese
/// tag haría que `setAudioSource` lance una excepción. En ese caso la radio
/// suena igual, solo sin controles en la notificación / pantalla de bloqueo.
bool radioBackgroundReady = false;

/// Estado simplificado de reproducción, expuesto para no acoplar el resto
/// de la app a la API interna de `just_audio`.
enum RadioPlaybackState { stopped, loading, playing, paused, error }

/// Fuente de audio con los metadatos (título/artista) que se muestran en la
/// notificación y en la pantalla de bloqueo mientras suena en segundo
/// plano. `just_audio_background` (inicializado en `main.dart`) necesita
/// este `tag` para poder armar esos controles.
AudioSource _buildRadioSource() {
  return AudioSource.uri(
    Uri.parse(kRadioStreamUrl),
    // Sin `just_audio_background` inicializado, el tag `MediaItem` no se puede
    // procesar y rompe la reproducción — se omite y la radio suena normal.
    tag: radioBackgroundReady
        ? const MediaItem(
            id: 'radio_doliv_live',
            title: 'Radio Doliv',
            artist: 'En vivo',
          )
        : null,
  );
}

/// Reproductor de radio en vivo compartido por toda la app.
///
/// Es un singleton a propósito: `MyAppBar` (donde vive el botón de radio)
/// se reconstruye cada vez que se navega a una pantalla nueva, y si cada
/// instancia creara su propio reproductor la transmisión se cortaría al
/// cambiar de pantalla. Con un único reproductor global, la radio sigue
/// sonando en segundo plano sin importar por dónde navegue el usuario.
///
/// Usa `just_audio` (no `audioplayers`) específicamente para este stream:
/// su motor en Android (ExoPlayer) sí entiende el protocolo ICY/Icecast que
/// manda Zeno.fm (metadatos de canción intercalados en el audio); el
/// `MediaPlayer` nativo de Android que usa `audioplayers` lo rechaza con
/// `MEDIA_ERROR_UNKNOWN`.
///
/// Además, va de la mano con `just_audio_background` (inicializado antes
/// que nada en `main.dart`, vía `JustAudioBackground.init(...)`), que
/// registra un foreground service en Android para que la radio siga
/// sonando con la app minimizada o la pantalla bloqueada, con controles de
/// play/pausa en la notificación y en el lock screen.
class RadioPlayer {
  RadioPlayer._internal() {
    unawaited(_preload());
  }

  static final RadioPlayer instance = RadioPlayer._internal();

  final AudioPlayer _player = AudioPlayer();
  final StreamController<RadioPlaybackState> _stateController =
      StreamController<RadioPlaybackState>.broadcast();
  final StreamController<String?> _nowPlayingController =
      StreamController<String?>.broadcast();

  RadioPlaybackState _state = RadioPlaybackState.stopped;
  double _volume = 1.0;
  String? _nowPlaying;
  Future<void>? _preloadFuture;
  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<IcyMetadata?>? _icySub;

  /// Emite cada vez que cambia el estado de reproducción, para que el
  /// widget del botón se actualice solo.
  Stream<RadioPlaybackState> get onStateChanged => _stateController.stream;

  RadioPlaybackState get state => _state;

  bool get isPlaying => _state == RadioPlaybackState.playing;

  /// Volumen actual (0.0 – 1.0).
  double get volume => _volume;

  /// Cambia el volumen del stream en vivo. Se limita a [0, 1].
  Future<void> setVolume(double value) async {
    _volume = value.clamp(0.0, 1.0);
    await _player.setVolume(_volume);
  }

  /// Título de lo que suena ahora (metadatos ICY del stream de Zeno.fm), o
  /// `null` si aún no llegó ninguno / la radio está detenida.
  String? get nowPlaying => _nowPlaying;

  /// Emite el título ICY cada vez que cambia la canción/segmento.
  Stream<String?> get onNowPlayingChanged => _nowPlayingController.stream;

  void _onPlayerState(PlayerState playerState) {
    RadioPlaybackState next;
    if (playerState.playing) {
      next = playerState.processingState == ProcessingState.buffering ||
              playerState.processingState == ProcessingState.loading
          ? RadioPlaybackState.loading
          : RadioPlaybackState.playing;
    } else if (playerState.processingState == ProcessingState.idle) {
      next = RadioPlaybackState.stopped;
    } else {
      next = RadioPlaybackState.paused;
    }
    _state = next;
    _stateController.add(next);

    // Al cortar la transmisión, lo que "sonaba" deja de tener sentido.
    if (next == RadioPlaybackState.stopped && _nowPlaying != null) {
      _nowPlaying = null;
      _nowPlayingController.add(null);
    }
  }

  void _onIcy(IcyMetadata? icy) {
    // Zeno.fm manda el título de la canción/segmento en `icy.info.title`.
    final title = icy?.info?.title?.trim();
    final next = (title == null || title.isEmpty) ? null : title;
    if (next == _nowPlaying) return;
    _nowPlaying = next;
    _nowPlayingController.add(next);
  }

  Future<void> _preload() {
    return _preloadFuture ??= () async {
      _playerStateSub ??= _player.playerStateStream.listen(_onPlayerState);
      _icySub ??= _player.icyMetadataStream.listen(_onIcy);
      try {
        // Precarga la conexión (DNS/TLS) para que el primer tap del
        // usuario se sienta más rápido; no evita que toggle() vuelva a
        // pedir la URL después, eso es intencional (ver toggle()).
        await _player.setAudioSource(_buildRadioSource(), preload: true);
      } catch (_) {
        // Si la precarga silenciosa falla (sin red, etc.), no pasa nada:
        // toggle() vuelve a intentar cuando el usuario toque el botón.
      }
    }();
  }

  /// Alterna entre reproducir y detener el stream en vivo.
  ///
  /// A propósito NO usamos `pause()`/`resume()`: para un stream en vivo eso
  /// dejaría el buffer "congelado" en el momento en que se pausó, así que
  /// al reanudar se escucharía justo donde se quedó (como una pausa de
  /// video), no lo que está sonando ahora. En vez de eso, al "pausar"
  /// cortamos la conexión por completo (`stop`), y al volver a dar play se
  /// pide la URL de nuevo — igual que hace la radio de verdad, siempre
  /// conecta al punto actual de la transmisión.
  Future<void> toggle() async {
    if (isPlaying || _state == RadioPlaybackState.loading) {
      await _player.stop();
      return;
    }

    _state = RadioPlaybackState.loading;
    _stateController.add(_state);

    try {
      // Siempre se vuelve a pedir la fuente (no se reutiliza la conexión
      // anterior) para garantizar que conecta al instante en vivo actual.
      await _player.setAudioSource(_buildRadioSource(), preload: true);
      await _player.play();
    } catch (e) {
      _state = RadioPlaybackState.error;
      _stateController.add(_state);
      rethrow;
    }
  }

  /// Corta la transmisión si está sonando o cargando. Idempotente: no pasa
  /// nada si ya está detenida. Se llama, por ejemplo, al cerrar sesión.
  Future<void> stop() async {
    if (_state == RadioPlaybackState.stopped) return;
    try {
      await _player.stop();
    } catch (_) {
      // Si el reproductor ya no está disponible, no hay nada que cortar.
    }
  }
}
