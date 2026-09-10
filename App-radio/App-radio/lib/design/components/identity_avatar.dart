import 'package:flutter/material.dart';
import 'package:doliv_social/design/tokens/colors.dart';

/// Avatar circular de una persona. Si tiene foto ([photoUrl]) se muestra
/// encima; si no hay foto, o si la descarga falla, queda visible el respaldo:
/// una inicial sobre un color determinístico (mismo [id] → siempre el mismo
/// color), tomado de una paleta fija de tokens — nunca un color aleatorio ni
/// un `Color(...)` suelto.
class IdentityAvatar extends StatelessWidget {
  const IdentityAvatar({
    super.key,
    required this.id,
    this.label,
    this.radius = 16,
    this.photoUrl,
  });

  /// Semilla del color. Conviene que sea algo estable y único de la persona
  /// (el correo), para que conserve su color en todas las pantallas.
  final String id;

  /// Texto del que sale la inicial. Por defecto, [id] — pero cuando la
  /// semilla es el correo hay que pasar aquí el nombre, o se vería la inicial
  /// del correo en vez de la de la persona.
  final String? label;

  final double radius;
  final String? photoUrl;

  // Getter (no campo): `AppColors.*` ya no es constante y además cambia con
  // el modo claro/oscuro, así que se resuelve en cada llamada.
  static List<Color> get _palette => [
        AppColors.accent,
        AppColors.accentStrong,
        AppColors.success,
        AppColors.warning,
        AppColors.error,
      ];

  static Color colorForId(String id) =>
      _palette[id.hashCode.abs() % _palette.length];

  @override
  Widget build(BuildContext context) {
    final color = colorForId(id);
    final source = (label ?? id).trim();
    final initial = source.isNotEmpty ? source[0].toUpperCase() : '?';
    final url = photoUrl;
    final hasPhoto = url != null && url.isNotEmpty;

    // La foto va como `foregroundImage` (se pinta SOBRE el child) en vez de
    // como `backgroundImage`: si la URL falla, Flutter descarta la capa de
    // arriba y la inicial sigue ahí, sin un círculo vacío ni una excepción.
    return CircleAvatar(
      radius: radius,
      backgroundColor: color.withValues(alpha: 0.16),
      foregroundImage: hasPhoto ? NetworkImage(url) : null,
      onForegroundImageError: hasPhoto ? (_, __) {} : null,
      child: Text(
        initial,
        style: TextStyle(
            color: color, fontWeight: FontWeight.w800, fontSize: radius * 0.75),
      ),
    );
  }
}
