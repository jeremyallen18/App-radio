import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../tokens/colors.dart';

/// Avatar circular. Si se pasa [photoUrl], intenta mostrar esa foto de
/// perfil; si falla (404 u otro error de red), cae silenciosamente al
/// avatar con inicial — nunca imprime errores en consola por fotos rotas.
class IdentityAvatar extends StatelessWidget {
  const IdentityAvatar({
    super.key,
    required this.id,
    this.radius = 16,
    this.photoUrl,
  });

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

  static Color colorForId(String id) =>
      _palette[id.hashCode.abs() % _palette.length];

  Widget _fallback() {
    final color = colorForId(id);
    final initial = id.trim().isNotEmpty ? id.trim()[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: radius,
      backgroundColor: color.withValues(alpha: 0.16),
      child: Text(
        initial,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: radius * 0.75,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = photoUrl?.trim();
    if (url == null || url.isEmpty) return _fallback();

    return CachedNetworkImage(
      imageUrl: url,
      imageBuilder: (_, image) => CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.surfaceBorder,
        backgroundImage: image,
      ),
      // Si la foto no existe (404) o falla la red, muestra el avatar
      // con inicial — sin lanzar excepciones al log.
      errorWidget: (_, __, ___) => _fallback(),
      // Mientras carga muestra el fallback para evitar flash de vacío.
      placeholder: (_, __) => _fallback(),
    );
  }
}
