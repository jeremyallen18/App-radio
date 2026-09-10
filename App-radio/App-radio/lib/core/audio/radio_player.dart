import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

/// Stream en vivo de Radio Doliv (Zeno.FM), igual que `RADIODOLIV_PAGINA/script.js`.
const String kRadioStreamUrl = 'https://stream.zeno.fm/vrfurwfubkhtv';

/// `true` solo si `JustAudioBackground.init()` funcionó en `main.dart`. Si falló,
/// usar el tag `MediaItem` haría que `setAudioSource` lance excepción.
bool radioBackgroundReady = false;

/// Estado de reproducción, desacoplado de la API interna de `just_audio`.
enum RadioPlaybackState { stopped, loading, playing, paused, error }

/// Limpia el título de los metadatos ICY: guion suelto o vacío ⇒ `null` (sin
/// metadatos), para que la UI muestre el programa al aire en su lugar.
String? normalizeIcyTitle(String? raw) {
  final t = raw?.trim();
  if (t == null || t.isEmpty) return null;
  if (RegExp(r'^[\s\-–—]+$').hasMatch(t)) return null;
  return t;
}

/// Fuente de audio del stream; el `tag` alimenta los controles en segundo plano.
AudioSource _buildRadioSource() {
  return AudioSource.uri(
    Uri.parse(kRadioStreamUrl),
    // Sin `just_audio_background` activo el tag rompe la reproducción; se omite.
    tag: radioBackgroundReady
        ? const MediaItem(
            id: 'radio_doliv_live',
            title: 'Radio Doliv',
            artist: 'En vivo',
          )
        : null,
  );
}

/// Reproductor de radio en vivo, singleton compartido por toda la app.
///
/// Singleton para que la transmisión no se corte al navegar (el botón vive en
/// `MyAppBar`, que se reconstruye por pantalla). Usa `just_audio` porque su
/// ExoPlayer entiende el ICY/Icecast de Zeno.fm; `audioplayers` lo rechaza. Va
/// con `just_audio_background` para sonar con la app en segundo plano.
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

  /// Emite en cada cambio de estado de reproducción.
  Stream<RadioPlaybackState> get onStateChanged => _stateController.stream;

  RadioPlaybackState get state => _state;

  bool get isPlaying => _state == RadioPlaybackState.playing;

  /// Volumen actual (0.0 – 1.0).
  double get volume => _volume;

  /// Ajusta el volumen del stream, limitado a [0, 1].
  Future<void> setVolume(double value) async {
    _volume = value.clamp(0.0, 1.0);
    await _player.setVolume(_volume);
  }

  /// Título de lo que suena ahora (ICY), o `null` si no hay / está detenida.
  String? get nowPlaying => _nowPlaying;

  /// Emite el título ICY en cada cambio de canción/segmento.
  Stream<String?> get onNowPlayingChanged => _nowPlayingController.stream;

  /// Traduce el estado de `just_audio` al enum propio y lo publica.
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

    // Al cortar, lo que "sonaba" deja de tener sentido.
    if (next == RadioPlaybackState.stopped && _nowPlaying != null) {
      _nowPlaying = null;
      _nowPlayingController.add(null);
    }
  }

  /// Publica el título ICY normalizado cuando cambia.
  void _onIcy(IcyMetadata? icy) {
    final next = normalizeIcyTitle(icy?.info?.title);
    if (next == _nowPlaying) return;
    _nowPlaying = next;
    _nowPlayingController.add(next);
  }

  /// Se suscribe a los streams del player y precarga la conexión (DNS/TLS) para
  /// que el primer tap se sienta rápido. Idempotente.
  Future<void> _preload() {
    return _preloadFuture ??= () async {
      _playerStateSub ??= _player.playerStateStream.listen(_onPlayerState);
      _icySub ??= _player.icyMetadataStream.listen(_onIcy);
      try {
        await _player.setAudioSource(_buildRadioSource(), preload: true);
      } catch (_) {
        // Sin red, etc.: `toggle()` reintenta al tocar el botón.
      }
    }();
  }

  /// Alterna reproducir / detener.
  ///
  /// Usa `stop` (no `pause`) y vuelve a pedir la URL en cada play: un stream en
  /// vivo pausado se quedaría congelado en ese punto en vez de seguir en directo.
  Future<void> toggle() async {
    if (isPlaying || _state == RadioPlaybackState.loading) {
      await _player.stop();
      return;
    }

    _state = RadioPlaybackState.loading;
    _stateController.add(_state);

    try {
      await _player.setAudioSource(_buildRadioSource(), preload: true);
      await _player.play();
    } catch (e) {
      _state = RadioPlaybackState.error;
      _stateController.add(_state);
      rethrow;
    }
  }

  /// Corta la transmisión si está activa. Idempotente (p. ej. al cerrar sesión).
  Future<void> stop() async {
    if (_state == RadioPlaybackState.stopped) return;
    try {
      await _player.stop();
    } catch (_) {
      // El reproductor ya no está disponible: nada que cortar.
    }
  }
}
