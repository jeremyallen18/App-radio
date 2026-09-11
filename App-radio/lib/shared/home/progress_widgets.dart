import 'package:flutter/material.dart';

import 'package:doliv_social/design/design.dart';

/// Punto de color + etiqueta para las leyendas de las gráficas de progreso.
class ProgressLegendDot extends StatelessWidget {
  const ProgressLegendDot(
      {super.key, required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          label,
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
      ],
    );
  }
}

/// Píldora "Ritmo activo": contorno tenue en verde con un punto que late.
/// Va en la esquina del encabezado de las pantallas de progreso.
class LivePulsePill extends StatefulWidget {
  const LivePulsePill({super.key, this.label = 'Ritmo activo'});

  final String label;

  @override
  State<LivePulsePill> createState() => _LivePulsePillState();
}

class _LivePulsePillState extends State<LivePulsePill>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    // El pulso solo corre si el usuario no pidió "reducir movimiento".
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || context.reduceMotion) return;
      setState(() {
        _controller = AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 1600),
        )..repeat();
      });
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 8,
            height: 8,
            child: controller == null
                ? _dot()
                : AnimatedBuilder(
                    animation: controller,
                    builder: (context, child) {
                      final t = Curves.easeOut.transform(controller.value);
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          Opacity(
                            opacity: (1 - t) * 0.7,
                            child: Transform.scale(
                              scale: 1 + t * 1.8,
                              child: _dot(),
                            ),
                          ),
                          _dot(),
                        ],
                      );
                    },
                  ),
          ),
          const SizedBox(width: 6),
          Text(
            widget.label,
            style: TextStyle(
              color: AppColors.success,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot() => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: AppColors.success,
          shape: BoxShape.circle,
        ),
      );
}

/// Color estable derivado de un id (para los avatares de departamento cuando
/// el backend no envía un color propio). Mismo id → mismo color siempre.
Color departmentAccent(String id) {
  const palette = [
    Color(0xFF6366F1), // indigo
    Color(0xFF0EA5E9), // sky
    Color(0xFF10B981), // emerald
    Color(0xFFF59E0B), // amber
    Color(0xFFEC4899), // pink
    Color(0xFF8B5CF6), // violet
    Color(0xFF14B8A6), // teal
    Color(0xFFEF4444), // red
  ];
  var hash = 0;
  for (final unit in id.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return palette[hash % palette.length];
}

/// Iniciales cortas para el avatar de un departamento ("Cabina y Redacción"
/// → "CR", "Ventas" → "VE").
String departmentInitials(String name) {
  final words =
      name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return '–';
  if (words.length == 1) {
    final w = words.first;
    return (w.length == 1 ? w : w.substring(0, 2)).toUpperCase();
  }
  return (words[0][0] + words[1][0]).toUpperCase();
}
