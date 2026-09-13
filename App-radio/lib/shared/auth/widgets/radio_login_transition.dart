import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A finite, silent sign-in handoff. The caller owns dashboard navigation.
class RadioLoginTransition extends StatefulWidget {
  const RadioLoginTransition({super.key, required this.onCompleted});

  final VoidCallback onCompleted;

  static const duration = Duration(milliseconds: 2200);

  @override
  State<RadioLoginTransition> createState() => _RadioLoginTransitionState();
}

class _RadioLoginTransitionState extends State<RadioLoginTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: RadioLoginTransition.duration,
  )..addStatusListener(_onStatus);
  bool _started = false;
  bool _completed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else if (!_started) {
      _controller.forward();
    }
    _started = true;
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || _completed) return;
    _completed = true;
    // Reduced motion can finish during build; navigate after that frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onCompleted();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxHeight < 640 ||
                  MediaQuery.textScalerOf(context).scale(1) > 1.4;
              final showLogo = constraints.maxHeight >= 450;
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: compact ? 16 : 32,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: AnimatedBuilder(
                          animation: _controller,
                          builder: (context, _) {
                            final progress = _controller.value;
                            final locked = progress >= 0.68;
                            final light = const Interval(
                              0.58,
                              0.78,
                              curve: Curves.easeOutCubic,
                            ).transform(progress);
                            return Semantics(
                              container: true,
                              liveRegion: true,
                              label: locked
                                  ? 'Inicio de sesi\u00f3n exitoso. Entrando a tu espacio.'
                                  : 'Inicio de sesi\u00f3n exitoso. Sintonizando tu espacio.',
                              child: ExcludeSemantics(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    if (showLogo) ...[
                                      Center(
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: const BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Image(
                                            image: const AssetImage(
                                                'assets/logo/logo.png'),
                                            width: compact ? 40 : 64,
                                            height: compact ? 40 : 64,
                                            fit: BoxFit.contain,
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: compact ? 8 : 16),
                                    ],
                                    Text(
                                      'Radio Doliv',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: colors.onSurface,
                                        fontSize: compact ? 22 : 26,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0,
                                      ),
                                    ),
                                    SizedBox(height: compact ? 12 : 32),
                                    Center(
                                      child: _OnAirIndicator(
                                          light: light, compact: compact),
                                    ),
                                    SizedBox(height: compact ? 12 : 28),
                                    RepaintBoundary(
                                      child: SizedBox(
                                        height: compact ? 100 : 136,
                                        width: double.infinity,
                                        child: CustomPaint(
                                          painter: _BroadcastPainter(
                                            progress: progress,
                                            signal: colors.secondary,
                                            ticks: colors.onSurfaceVariant,
                                            indicator: colors.error,
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: compact ? 12 : 24),
                                    // Both labels reserve space, including at large text sizes.
                                    Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        for (final state in [false, true])
                                          Opacity(
                                            opacity: locked == state ? 1 : 0,
                                            child: Text(
                                              state
                                                  ? 'Tu equipo, al aire'
                                                  : 'Sintonizando tu espacio',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: colors.onSurface,
                                                fontSize: compact ? 16 : 18,
                                                fontWeight: FontWeight.w600,
                                                letterSpacing: 0,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    if (!compact) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        'Entrando a tu espacio',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: colors.onSurfaceVariant,
                                          fontSize: 14,
                                          letterSpacing: 0,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _OnAirIndicator extends StatelessWidget {
  const _OnAirIndicator({required this.light, required this.compact});

  final double light;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    const onAirRed = Color(0xFFB91C1C);
    final foreground =
        Color.lerp(colors.onSurfaceVariant, Colors.white, light)!;

    return Container(
      width: 224,
      height: compact ? 60 : 76,
      padding:
          EdgeInsets.symmetric(horizontal: 24, vertical: compact ? 10 : 16),
      decoration: BoxDecoration(
        color: Color.lerp(colors.surface, onAirRed, light),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Color.lerp(colors.outline, onAirRed, light)!,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: onAirRed.withValues(alpha: light * 0.28),
            blurRadius: 24 * light,
            spreadRadius: 2 * light,
          ),
        ],
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration:
                  BoxDecoration(color: foreground, shape: BoxShape.circle),
            ),
            const SizedBox(width: 12),
            Text(
              'ON AIR',
              style: TextStyle(
                color: foreground,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BroadcastPainter extends CustomPainter {
  const _BroadcastPainter({
    required this.progress,
    required this.signal,
    required this.ticks,
    required this.indicator,
  });

  final double progress;
  final Color signal;
  final Color ticks;
  final Color indicator;

  static final _needle = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(begin: 0.12, end: 0.82)
          .chain(CurveTween(curve: Curves.easeInOutCubic)),
      weight: 40,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 0.82, end: 0.44)
          .chain(CurveTween(curve: Curves.easeInOutCubic)),
      weight: 35,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 0.44, end: 0.5)
          .chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 25,
    ),
  ]);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final settle =
        const Interval(0.36, 0.68, curve: Curves.easeInOut).transform(progress);
    // Freeze the carrier at lock so the last frame reads as a stable signal.
    final time = math.min(progress, 0.68) * 18;
    final pen = Paint()..strokeCap = StrokeCap.round;
    final waveY = size.height * 0.27;
    final waveHeight = size.height * 0.4;
    const bars = 45;
    final gap = size.width / bars;
    pen.strokeWidth = math.min(4, gap * 0.48);
    for (var i = 0; i < bars; i++) {
      final x = (i + 0.5) * gap;
      final envelope = math.sin((i + 0.5) / bars * math.pi);
      final noise =
          (math.sin(i * 2.7 + time * 2) + math.sin(i * 1.3 - time * 3)).abs() /
              2;
      final carrier = math.sin(i * 0.48 + time).abs();
      final amplitude = noise * (1 - settle) + carrier * settle;
      final height = 4 + envelope * (8 + amplitude * (waveHeight - 8));
      pen.color = signal.withValues(alpha: 0.4 + envelope * 0.6);
      canvas.drawLine(
          Offset(x, waveY - height / 2), Offset(x, waveY + height / 2), pen);
    }

    pen.strokeWidth = 1;
    pen.color = ticks.withValues(alpha: 0.4);
    canvas.drawLine(
        Offset(0, size.height - 5), Offset(size.width, size.height - 5), pen);
    for (var i = 0; i <= 40; i++) {
      final x = i / 40 * size.width;
      final major = i % 5 == 0;
      pen.color = ticks.withValues(alpha: major ? 0.85 : 0.4);
      canvas.drawLine(Offset(x, size.height - 5),
          Offset(x, size.height - (major ? 24 : 15)), pen);
    }

    final tuning = const Interval(0.04, 0.64).transform(progress);
    final needleX = _needle.transform(tuning) * size.width;
    pen
      ..color = indicator
      ..strokeWidth = 3;
    canvas.drawLine(Offset(needleX, size.height - 38),
        Offset(needleX, size.height - 2), pen);
    canvas.drawCircle(Offset(needleX, size.height - 41), 3, pen);
  }

  @override
  bool shouldRepaint(_BroadcastPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.signal != signal ||
      oldDelegate.ticks != ticks ||
      oldDelegate.indicator != indicator;
}
