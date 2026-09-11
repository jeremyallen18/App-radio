import 'package:flutter/material.dart';

import 'package:doliv_social/design/tokens/colors.dart';
import 'package:doliv_social/design/tokens/spacing.dart';
import 'package:doliv_social/design/components/identity_avatar.dart';

/// Encabezado de una ficha de persona: banda de marca, foto sobre el borde,
/// nombre, puesto e insignias. Compartido por el perfil propio (pasa
/// [onEditPhoto]) y la ficha de un compañero.
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.name,
    required this.headline,
    this.photoUrl,
    this.avatarSeed,
    this.badges = const [],
    this.footer,
    this.onEditPhoto,
    this.uploadingPhoto = false,
  });

  final String name;

  /// Línea bajo el nombre: el puesto, o el rol si no tiene puesto.
  final String headline;
  final String? photoUrl;

  /// Semilla del color de respaldo del avatar (para que sea estable por persona).
  final String? avatarSeed;

  /// Insignias de rol/departamento. Se envuelven en varias líneas si no caben.
  final List<Widget> badges;

  /// Contenido opcional bajo un separador (contacto, acciones).
  final Widget? footer;

  /// Si se pasa, aparece el botón de cámara sobre el avatar.
  final VoidCallback? onEditPhoto;
  final bool uploadingPhoto;

  static const double _bandHeight = 84;
  static const double _avatarRadius = 44;

  /// Grosor del anillo del color de la tarjeta alrededor de la foto.
  static const double _ringWidth = 3;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // El avatar queda centrado sobre el borde inferior de la banda.
          Stack(
            alignment: Alignment.topCenter,
            children: [
              ClipRect(
                child: Container(
                  height: _bandHeight,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.brandBlue, AppColors.brandNavy],
                    ),
                  ),
                  child: CustomPaint(painter: _DotGridPainter()),
                ),
              ),
              Positioned(
                top: AppSpacing.sm,
                right: AppSpacing.sm,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.24),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: const Text(
                    '📻 Radio Doliv',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(
                  top: _bandHeight - _avatarRadius - _ringWidth,
                ),
                child: _Avatar(
                  seed: avatarSeed ?? name,
                  name: name,
                  photoUrl: photoUrl,
                  radius: _avatarRadius,
                  ringWidth: _ringWidth,
                  onEdit: onEditPhoto,
                  uploading: uploadingPhoto,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              children: [
                Text(
                  name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  headline,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: AppColors.textMuted),
                ),
                if (badges.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: badges,
                  ),
                ],
                if (footer != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Divider(height: 1, color: AppColors.surfaceBorder),
                  const SizedBox(height: AppSpacing.md),
                  footer!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.seed,
    required this.name,
    required this.photoUrl,
    required this.radius,
    required this.ringWidth,
    required this.onEdit,
    required this.uploading,
  });

  final String seed;
  final String name;
  final String? photoUrl;
  final double radius;
  final double ringWidth;
  final VoidCallback? onEdit;
  final bool uploading;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Resplandor azul detrás del anillo, para que el avatar destaque
        // sobre la banda de marca.
        Container(
          width: (radius + ringWidth) * 2,
          height: (radius + ringWidth) * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.accentStrong.withValues(alpha: 0.55),
                blurRadius: 20,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
        // Anillo del color de la tarjeta que recorta el avatar contra la banda.
        Container(
          padding: EdgeInsets.all(ringWidth),
          decoration: BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
          ),
          child: IdentityAvatar(
            id: seed,
            label: name,
            radius: radius,
            photoUrl: photoUrl,
          ),
        ),
        if (uploading)
          Positioned.fill(
            child: Container(
              margin: EdgeInsets.all(ringWidth),
              decoration: BoxDecoration(
                color: AppColors.bgBase.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        if (onEdit != null)
          Positioned(
            bottom: 0,
            right: 0,
            child: Material(
              color: AppColors.bgBase,
              shape: CircleBorder(
                side: BorderSide(color: AppColors.surfaceBorder),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: uploading ? null : onEdit,
                child: Padding(
                  padding: EdgeInsets.all(7),
                  child: Icon(
                    Icons.photo_camera_outlined,
                    size: 16,
                    color: AppColors.accentStrong,
                    semanticLabel: 'Cambiar foto de perfil',
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Textura decorativa de la banda de marca: una retícula fina de puntos
/// blancos translúcidos, como en la referencia de diseño. Puramente estética,
/// no reacciona a nada.
class _DotGridPainter extends CustomPainter {
  static const double _gap = 14;
  static const double _dotRadius = 1.1;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.16);
    for (double y = _gap / 2; y < size.height; y += _gap) {
      for (double x = _gap / 2; x < size.width; x += _gap) {
        canvas.drawCircle(Offset(x, y), _dotRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotGridPainter oldDelegate) => false;
}
