import 'package:flutter/material.dart';
import '../tokens/colors.dart';

/// Avatar circular con la inicial de un nombre/correo y un color
/// determinístico (mismo id → siempre el mismo color), tomado de una
/// paleta fija de tokens — nunca un color aleatorio ni un `Color(...)` suelto.
class IdentityAvatar extends StatelessWidget {
  const IdentityAvatar({super.key, required this.id, this.radius = 16});

  final String id;
  final double radius;

  static const List<Color> _palette = [
    AppColors.accent,
    AppColors.accentStrong,
    AppColors.success,
    AppColors.warning,
    AppColors.error,
  ];

  static Color colorForId(String id) => _palette[id.hashCode.abs() % _palette.length];

  @override
  Widget build(BuildContext context) {
    final color = colorForId(id);
    final initial = id.trim().isNotEmpty ? id.trim()[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: radius,
      backgroundColor: color.withValues(alpha: 0.16),
      child: Text(
        initial,
        style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: radius * 0.75),
      ),
    );
  }
}
