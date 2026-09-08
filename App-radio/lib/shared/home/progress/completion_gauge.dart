import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:doliv_social/design/design.dart';

/// Medidor de aguja tipo VU: semicírculo con un arco de tres segmentos
/// (completadas · en progreso · pendientes), marcas cada 10 % y la aguja
/// apuntando al porcentaje completado. Al montarse, arco y aguja "suben"
/// desde cero; con animaciones desactivadas aparece ya en su valor.
class CompletionGauge extends StatelessWidget {
  const CompletionGauge({
    super.key,
    required this.done,
    required this.inProgress,
    required this.pending,
    this.caption = 'completado',
  });

  final int done;
  final int inProgress;
  final int pending;
  final String caption;

  int get _total => done + inProgress + pending;
  double get _ratio => _total == 0 ? 0 : done / _total;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final pct = (_ratio * 100).round();
    return AspectRatio(
      aspectRatio: 1.9,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: reduceMotion ? 1 : 0, end: 1),
        duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, t, _) {
          return CustomPaint(
            painter: _GaugePainter(
              done: done,
              inProgress: inProgress,
              pending: pending,
              progress: t,
            ),
            child: Align(
              alignment: const Alignment(0, 0.8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${(pct * t).round()}%',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      height: 1,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    caption,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({
    required this.done,
    required this.inProgress,
    required this.pending,
    required this.progress,
  });

  final int done;
  final int inProgress;
  final int pending;

  /// 0..1 de la animación de entrada.
  final double progress;

  static const double _stroke = 18;
  static const double _gap = 0.035; // radianes entre segmentos

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height - 6);
    final radius = math.min(size.width / 2, size.height) - _stroke;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final total = done + inProgress + pending;

    // Pista de fondo.
    canvas.drawArc(
      rect,
      math.pi,
      math.pi,
      false,
      Paint()
        ..color = AppColors.surfaceBorder
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..strokeCap = StrokeCap.butt,
    );

    // Segmentos (todos crecen con `progress`).
    if (total > 0) {
      final segments = [
        (done, AppColors.success),
        (inProgress, AppColors.accent),
        (pending, AppColors.warning),
      ].where((s) => s.$1 > 0).toList();
      var start = math.pi;
      final gaps = segments.length > 1 ? _gap * (segments.length - 1) : 0.0;
      final usable = (math.pi - gaps) * progress;
      for (final (count, color) in segments) {
        final sweep = usable * count / total;
        canvas.drawArc(
          rect,
          start,
          sweep,
          false,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = _stroke
            ..strokeCap = StrokeCap.butt,
        );
        start += sweep + _gap * progress;
      }
    }

    // Marcas cada 10 % por fuera del arco.
    final tick = Paint()
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i <= 10; i++) {
      final a = math.pi + math.pi * i / 10;
      final major = i % 5 == 0;
      final r1 = radius + _stroke / 2 + 5;
      final r2 = r1 + (major ? 9 : 5);
      tick.color = AppColors.textMuted.withValues(alpha: major ? 0.8 : 0.4);
      canvas.drawLine(
        center + Offset(math.cos(a), math.sin(a)) * r1,
        center + Offset(math.cos(a), math.sin(a)) * r2,
        tick,
      );
    }

    // Aguja al % completado. Vive solo en el anillo exterior (del 62 % del
    // radio hasta el arco) para no cruzar el número del centro.
    final ratio = total == 0 ? 0.0 : done / total;
    final angle = math.pi + math.pi * ratio * progress;
    final dir = Offset(math.cos(angle), math.sin(angle));
    final tip = center + dir * (radius + _stroke / 2 + 2);
    final tail = center + dir * (radius * 0.62);
    canvas.drawLine(
      tail,
      tip,
      Paint()
        ..color = AppColors.accentStrong.withValues(alpha: 0.35)
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawLine(
      tail,
      tip,
      Paint()
        ..color = AppColors.textPrimary
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
    // Punta de la aguja sobre el arco.
    canvas.drawCircle(tip, 4, Paint()..color = AppColors.textPrimary);
    canvas.drawCircle(
      tip,
      4,
      Paint()
        ..color = AppColors.accentStrong
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.done != done ||
      old.inProgress != inProgress ||
      old.pending != pending ||
      old.progress != progress;
}
