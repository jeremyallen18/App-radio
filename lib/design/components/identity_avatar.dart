import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../tokens/colors.dart';

/// Avatar circular. Si se pasa [photoUrl], muestra esa foto de perfil
/// (tipo WhatsApp); si no hay foto, cae de vuelta al avatar con la
/// inicial de un nombre/correo y un color determinístico (mismo id →
/// siempre el mismo color), tomado de una paleta fija de tokens — nunca un
/// color aleatorio ni un `Color(...)` suelto.
class IdentityAvatar extends StatelessWidget {
  const IdentityAvatar({super.key, required this.id, this.radius = 16, this.photoUrl});

  final String id;
  final double radius;
  final String? photoUrl;

  static List<Color> get _palette => [
    AppColors.accent,
    AppColors.accentStrong,
    AppColors.success,
    AppColors.warning,
    AppColors.error,
  ];

  static Color colorForId(String id) => _palette[id.hashCode.abs() % _palette.length];

  @override
  Widget build(BuildContext context) {
    if (photoUrl != null && photoUrl!.trim().isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.surfaceBorder,
        backgroundImage: CachedNetworkImageProvider(photoUrl!),
      );
    }

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
