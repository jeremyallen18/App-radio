import 'dart:async';

import 'package:flutter/material.dart';

import 'package:doliv_social/core/audio/radio_player.dart';
import 'package:doliv_social/design/motion/app_motion.dart';
import 'package:doliv_social/design/tokens/colors.dart';

/// Control compacto de la transmisión en vivo, en el header de la app (ver
/// `lib/shared/widgets/appbar.dart`).
///
/// - El círculo blanco = reproducir / detener.
/// - La etiqueta "Doliv en vivo ▾" = abrir [onExpand] (panel con volumen, lo
///   que suena y la programación del día). Si [onExpand] es null, la etiqueta
///   no reacciona.
class RadioPlayerButton extends StatefulWidget {
  const RadioPlayerButton({super.key, this.onExpand});

  /// Abre el panel ampliado del reproductor. Lo provee `MyAppBar`.
  final VoidCallback? onExpand;

  @override
  State<RadioPlayerButton> createState() => _RadioPlayerButtonState();
}

const double _kDiscSize = 30;

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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Disc(
          playing: _isPlaying,
          loading: _isLoading,
          onTap: _isLoading ? null : _toggle,
        ),
        const SizedBox(width: 8),
        // Se encoge (elipsis) en pantallas angostas sin desbordar el header.
        Flexible(child: _Label(playing: _isPlaying, onExpand: widget.onExpand)),
      ],
    );
  }
}

/// Disco blanco. Triángulo de play / cuadrado de stop en color de fondo.
/// Mientras suena, el punto verde "en vivo" late con un anillo suave y el
/// glifo cambia con un cross-fade. El bucle solo corre cuando `playing` es
/// `true` y se detiene en cuanto para (o con "reducir movimiento").
class _Disc extends StatefulWidget {
  const _Disc({required this.playing, required this.loading, this.onTap});

  final bool playing;
  final bool loading;
  final VoidCallback? onTap;

  @override
  State<_Disc> createState() => _DiscState();
}

class _DiscState extends State<_Disc> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: AppDurations.pulse,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPulse();
  }

  @override
  void didUpdateWidget(covariant _Disc oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.playing != oldWidget.playing) _syncPulse();
  }

  void _syncPulse() {
    final bool shouldRun = widget.playing && !context.reduceMotion;
    if (shouldRun && !_pulse.isAnimating) {
      _pulse.repeat();
    } else if (!shouldRun && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool playing = widget.playing;
    final Widget glyph;
    if (widget.loading) {
      glyph = const SizedBox(
        key: ValueKey('loading'),
        width: 14,
        height: 14,
        child:
            CircularProgressIndicator(strokeWidth: 2, color: AppColors.bgBase),
      );
    } else {
      glyph = Icon(
        playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
        key: ValueKey(playing ? 'stop' : 'play'),
        color: AppColors.bgBase,
        size: 20,
      );
    }

    return Tooltip(
      message: playing ? 'Pausar radio en vivo' : 'Escuchar radio en vivo',
      child: Material(
        color: AppColors.textPrimary,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          child: SizedBox(
            width: _kDiscSize,
            height: _kDiscSize,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Center(
                  child: AnimatedSwitcher(
                    duration: AppDurations.short,
                    child: glyph,
                  ),
                ),
                if (playing)
                  Positioned(
                    right: 2,
                    top: 2,
                    child: _LiveDot(pulse: _pulse),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Punto verde "en vivo" con un anillo que se expande y desvanece al ritmo
/// de [pulse].
class _LiveDot extends StatelessWidget {
  const _LiveDot({required this.pulse});

  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, child) {
        final double t = pulse.value;
        return SizedBox(
          width: 8,
          height: 8,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              if (t > 0)
                Opacity(
                  opacity: (1 - t) * 0.55,
                  child: Transform.scale(
                    scale: 1 + t * 2.2,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              child!,
            ],
          ),
        );
      },
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: AppColors.success,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.textPrimary, width: 1.5),
        ),
      ),
    );
  }
}

/// "Doliv en vivo ▾" — abre el panel ampliado al tocarla.
class _Label extends StatelessWidget {
  const _Label({required this.playing, this.onExpand});

  final bool playing;
  final VoidCallback? onExpand;

  @override
  Widget build(BuildContext context) {
    final text = Flexible(
      child: Text(
        playing ? 'En vivo' : 'Doliv en vivo',
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.clip,
        style: TextStyle(
          fontSize: 13,
          height: 1,
          fontWeight: FontWeight.w600,
          color: playing ? AppColors.success : AppColors.textPrimary,
        ),
      ),
    );

    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        text,
        if (onExpand != null) ...[
          const SizedBox(width: 1),
          const Icon(Icons.keyboard_arrow_down_rounded,
              size: 16, color: AppColors.textMuted),
        ],
      ],
    );

    if (onExpand == null) return row;
    return Tooltip(
      message: 'Más controles y programación',
      child: InkWell(
        onTap: onExpand,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
          child: row,
        ),
      ),
    );
  }
}
