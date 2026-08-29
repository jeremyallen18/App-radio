import 'dart:async';

import 'package:flutter/material.dart';

import '../../utils/radio_player.dart';
import '../tokens/colors.dart';

/// Botón compacto para escuchar la transmisión en vivo de Radio Doliv.
/// Pensado para vivir en el header de la app, al lado del ícono de
/// notificaciones (ver `lib/models/appbar.dart`).
///
/// Mientras la radio está pausada/detenida, muestra una burbujita animada
/// a la izquierda del botón ("DOLIV En Vivo") que se desvanece en
/// cuanto empieza a sonar.
class RadioPlayerButton extends StatefulWidget {
  const RadioPlayerButton({super.key});

  @override
  State<RadioPlayerButton> createState() => _RadioPlayerButtonState();
}

/// Tamaño de referencia de los botones del header (play/campanita).
const double _kHeaderButtonSize = 48;

/// Tamaño FIJO y exacto de la burbuja (ancho y alto). Usar valores fijos
/// aquí -en vez de dejar que el contenido "decida" su propio tamaño- evita
/// por completo los errores de restricciones infinitas que causaban el
/// rectángulo rojo de error.
const double _kBubbleWidth = 122;
const double _kBubbleHeight = 26;

class _RadioPlayerButtonState extends State<RadioPlayerButton>
    with SingleTickerProviderStateMixin {
  RadioPlaybackState _state = RadioPlaybackState.stopped;
  StreamSubscription<RadioPlaybackState>? _sub;

  late final AnimationController _hintController;
  late final Animation<double> _hintNudge;

  @override
  void initState() {
    super.initState();
    _state = RadioPlayer.instance.state;
    _sub = RadioPlayer.instance.onStateChanged.listen((state) {
      if (!mounted) return;
      setState(() => _state = state);
    });

    // Animación en bucle: la burbuja "respira" hacia el botón y hacia atrás,
    // para llamar la atención sin ser demasiado invasiva.
    _hintController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..repeat(reverse: true);
    _hintNudge = Tween<double>(begin: 0, end: -6).animate(
      CurvedAnimation(parent: _hintController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    _hintController.dispose();
    super.dispose();
  }

  bool get _isPlaying => _state == RadioPlaybackState.playing;
  bool get _isLoading => _state == RadioPlaybackState.loading;

  Future<void> _toggle() async {
    try {
      await RadioPlayer.instance.toggle();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo conectar con la transmisión en vivo.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // La burbuja solo tiene sentido cuando invita a "dar play": se oculta
    // en cuanto está sonando (o mientras conecta, para no estorbar).
    final bool showHint = !_isPlaying && !_isLoading;

    return SizedBox(
      // Ancla el tamaño del botón en sí (sin la burbuja, que se dibuja por
      // fuera gracias a Clip.none) para que coincida con la campanita.
      height: _kHeaderButtonSize,
      width: _kHeaderButtonSize,
      child: Tooltip(
        message: _isPlaying ? 'Pausar radio en vivo' : 'Escuchar radio en vivo',
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              onPressed: _isLoading ? null : _toggle,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      _isPlaying
                          ? Icons.stop_circle_rounded
                          : Icons.play_circle_fill_rounded,
                      color: Colors.white,
                    ),
            ),
            if (_isPlaying)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Color.fromARGB(255, 0, 255, 255),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            // Burbuja animada apuntando al botón desde la izquierda.
            // width/height fijos: elimina cualquier ambigüedad de tamaño
            // (nada de restricciones infinitas ni auto-tamaño impredecible).
            Positioned(
              top: (_kHeaderButtonSize - _kBubbleHeight) / 2,
              right: _kHeaderButtonSize + 4,
              width: _kBubbleWidth,
              height: _kBubbleHeight,
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: showHint ? 1 : 0,
                  duration: const Duration(milliseconds: 300),
                  child: AnimatedBuilder(
                    animation: _hintNudge,
                    builder: (context, child) => Transform.translate(
                      offset: Offset(_hintNudge.value, 0),
                      child: child,
                    ),
                    child: const _RadioHintBubble(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Capsulita azul tipo globo de diálogo, con esquinas curvas y una colita
/// que apunta hacia el botón de radio. Ocupa exactamente el tamaño fijo
/// que le da el `Positioned` que la contiene (ver arriba).
class _RadioHintBubble extends StatelessWidget {
  const _RadioHintBubble();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.max,
      children: [
        Flexible(
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: AppColors.brandBlue,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white24),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black45,
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: const Text(
              'DOLIV En Vivo',
              style: TextStyle(
                color: Color.fromARGB(255, 0, 255, 255),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              textAlign: TextAlign.center,
            ),
          ),
        ),
        // Colita del globo: un cuadrito rotado 45° pegado al borde derecho
        // de la cápsula, apuntando hacia el botón de reproducción.
        // Nota: usamos Transform.translate (no `margin` negativo) para
        // acercarla a la cápsula, porque Container no admite márgenes
        // negativos (dispara un assertion error de Flutter).
        Transform.translate(
          offset: const Offset(-4, 0),
          child: Transform.rotate(
            angle: 0.785398, // 45 grados en radianes
            child: Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(color: AppColors.brandBlue),
            ),
          ),
        ),
      ],
    );
  }
}
