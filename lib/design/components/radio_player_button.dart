import 'dart:async';

import 'package:flutter/material.dart';

import 'package:doliv_social/core/audio/radio_player.dart';
import 'package:doliv_social/design/tokens/colors.dart';

/// Botón compacto para escuchar la transmisión en vivo de Radio Doliv.
/// Vive en el header de la app, al lado del ícono de notificaciones (ver
/// `lib/shared/widgets/appbar.dart`), con el mismo tratamiento visual
/// (círculo `AppColors.surface`) que ese botón.
///
/// - Tocar el botón redondo = reproducir / detener.
/// - Tocar la etiqueta de abajo = abrir [onExpand] (panel con volumen, lo
///   que suena y acceso a la programación del día). Si [onExpand] es null,
///   la etiqueta es solo decorativa.
class RadioPlayerButton extends StatefulWidget {
  const RadioPlayerButton({super.key, this.onExpand});

  /// Abre el panel ampliado del reproductor. Lo provee `MyAppBar`.
  final VoidCallback? onExpand;

  @override
  State<RadioPlayerButton> createState() => _RadioPlayerButtonState();
}

/// Tamaño de referencia de los botones del header (play/campanita).
const double _kHeaderButtonSize = 48;

class _RadioPlayerButtonState extends State<RadioPlayerButton> {
  RadioPlaybackState _state = RadioPlaybackState.stopped;
  StreamSubscription<RadioPlaybackState>? _sub;

  @override
  void initState() {
    super.initState();
    _state = RadioPlayer.instance.state;
    _sub = RadioPlayer.instance.onStateChanged.listen((state) {
      if (!mounted) return;
      setState(() => _state = state);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: _kHeaderButtonSize,
          width: _kHeaderButtonSize,
          child: Tooltip(
            message:
                _isPlaying ? 'Pausar radio en vivo' : 'Escuchar radio en vivo',
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: _isLoading ? null : _toggle,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.textPrimary,
                            ),
                          )
                        : Icon(
                            _isPlaying
                                ? Icons.stop_circle_rounded
                                : Icons.play_circle_fill_rounded,
                            color: AppColors.textPrimary,
                          ),
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
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 2),
        // Etiqueta discreta debajo del botón. Al tocarla se abre el panel
        // ampliado (volumen, lo que suena, programación del día).
        _CaptionLabel(
          playing: _isPlaying,
          onExpand: widget.onExpand,
        ),
      ],
    );
  }
}

class _CaptionLabel extends StatelessWidget {
  const _CaptionLabel({required this.playing, this.onExpand});
  final bool playing;
  final VoidCallback? onExpand;

  @override
  Widget build(BuildContext context) {
    final color = playing ? AppColors.success : AppColors.textMuted;
    final label = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          playing ? 'En vivo' : 'Doliv en vivo',
          style: TextStyle(
            fontSize: 9,
            height: 1,
            letterSpacing: 0.3,
            fontWeight: playing ? FontWeight.w700 : FontWeight.w500,
            color: color,
          ),
        ),
        if (onExpand != null) ...[
          const SizedBox(width: 2),
          Icon(Icons.keyboard_arrow_up_rounded, size: 11, color: color),
        ],
      ],
    );

    if (onExpand == null) return label;
    return Tooltip(
      message: 'Más controles y programación',
      child: InkWell(
        onTap: onExpand,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: label,
        ),
      ),
    );
  }
}
