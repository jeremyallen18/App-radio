import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:doliv_social/design/motion/app_motion.dart';

/// Pequeño estallido de confeti que se dibuja sobre toda la pantalla y se
/// limpia solo. Sin dependencias: un puñado de partículas de color que salen
/// del centro-inferior y caen. Con "reducir movimiento" no hace nada.
///
/// Pensado para celebrar el completado de una tarea, a la manera del
/// `canvas-confetti` del prototipo de rediseño.
void celebrateBurst(BuildContext context) {
  if (context.reduceMotion) return;
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _BurstLayer(onDone: () => entry.remove()),
  );
  overlay.insert(entry);
}

class _BurstLayer extends StatefulWidget {
  const _BurstLayer({required this.onDone});

  final VoidCallback onDone;

  @override
  State<_BurstLayer> createState() => _BurstLayerState();
}

class _BurstLayerState extends State<_BurstLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    final rnd = math.Random();
    const colors = [
      Color(0xFF60A5FA), // blue-400
      Color(0xFF2563EB), // blue-600
      Color(0xFFBFDBFE), // blue-200
      Colors.white,
    ];
    _particles = List.generate(18, (i) {
      final angle = -math.pi / 2 + (rnd.nextDouble() - 0.5) * 2.2;
      final speed = 260 + rnd.nextDouble() * 220;
      return _Particle(
        color: colors[i % colors.length],
        vx: math.cos(angle) * speed,
        vy: math.sin(angle) * speed,
        size: 6 + rnd.nextDouble() * 6,
        spin: (rnd.nextDouble() - 0.5) * 8,
      );
    });
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.onDone();
      });
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          size: Size.infinite,
          painter: _BurstPainter(_particles, _c.value),
        ),
      ),
    );
  }
}

class _Particle {
  _Particle({
    required this.color,
    required this.vx,
    required this.vy,
    required this.size,
    required this.spin,
  });

  final Color color;
  final double vx;
  final double vy;
  final double size;
  final double spin;
}

class _BurstPainter extends CustomPainter {
  _BurstPainter(this.particles, this.t);

  final List<_Particle> particles;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, size.height * 0.72);
    const gravity = 620.0;
    final fade = (1.0 - t).clamp(0.0, 1.0);

    for (final p in particles) {
      final x = origin.dx + p.vx * t;
      final y = origin.dy + p.vy * t + 0.5 * gravity * t * t;
      final paint = Paint()..color = p.color.withValues(alpha: fade);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.spin * t);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.t != t;
}
