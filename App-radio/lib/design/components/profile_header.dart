import 'package:flutter/material.dart';

import 'package:doliv_social/design/tokens/colors.dart';
import 'package:doliv_social/design/tokens/spacing.dart';
import 'package:doliv_social/design/components/identity_avatar.dart';

/// Encabezado de una ficha de persona: banda de marca, foto encima del
/// borde, nombre, puesto y las insignias que describen su lugar en la
/// organización (rol, departamento…).
///
/// Lo usan tanto el perfil propio (`home_page/profile.dart`, que además pasa
/// [onEditPhoto]) como la ficha de un compañero
/// (`screens/directory/colleague_profile_screen.dart`), para que las dos se
/// vean como la misma pantalla vista desde distinto lado.
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

  /// Semilla del color de respaldo del avatar. Por defecto el correo o
  /// nombre que se muestre; sirve para que la misma persona conserve su
  /// color en el directorio y en su ficha.
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
          // El avatar queda centrado sobre el borde inferior de la banda: la
          // mitad de arriba encima del degradado y la de abajo sobre la
          // tarjeta, así que el encabezado se lee como una sola pieza.
          Stack(
            alignment: Alignment.topCenter,
            children: [
              Container(
                height: _bandHeight,
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.brandBlue, AppColors.brandNavy],
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
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  headline,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
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
                  const Divider(height: 1, color: AppColors.surfaceBorder),
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
        // Anillo del color de la tarjeta: recorta el avatar contra la banda
        // de marca para que se lea como una capa encima, no como un parche.
        Container(
          padding: EdgeInsets.all(ringWidth),
          decoration: const BoxDecoration(
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
              child: const Center(
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
              shape: const CircleBorder(
                side: BorderSide(color: AppColors.surfaceBorder),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: uploading ? null : onEdit,
                child: const Padding(
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
