import 'package:flutter/material.dart';

import 'package:doliv_social/design/design.dart';

/// Banda de marca a todo lo ancho con la foto superpuesta, a la manera de
/// una cabecera de perfil de X: sin tarjeta, sin bordes — la pantalla misma
/// es el encabezado.
class ProfileHero extends StatelessWidget {
  const ProfileHero({
    super.key,
    required this.name,
    required this.headline,
    required this.photoUrl,
    required this.avatarSeed,
    required this.onEditPhoto,
    required this.uploadingPhoto,
  });

  final String name;
  final String headline;
  final String? photoUrl;
  final String avatarSeed;
  final VoidCallback onEditPhoto;
  final bool uploadingPhoto;

  static const double _bandHeight = 120;
  static const double _avatarRadius = 44;
  static const double _ringWidth = 4;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          clipBehavior: Clip.none,
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
            // El avatar se coloca con `Padding` (no `Positioned`) para que el
            // `Stack` crezca y contenga la parte que sobresale de la banda; si
            // no, el nombre de abajo se montaría encima de la foto.
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.lg,
                top: _bandHeight - _avatarRadius - _ringWidth,
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(_ringWidth),
                    decoration: const BoxDecoration(
                      color: AppColors.bgBase,
                      shape: BoxShape.circle,
                    ),
                    child: IdentityAvatar(
                      id: avatarSeed,
                      label: name,
                      radius: _avatarRadius,
                      photoUrl: photoUrl,
                    ),
                  ),
                  if (uploadingPhoto)
                    Positioned.fill(
                      child: Container(
                        margin: const EdgeInsets.all(_ringWidth),
                        decoration: BoxDecoration(
                          color: AppColors.bgBase.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
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
                        onTap: uploadingPhoto ? null : onEditPhoto,
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
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                headline,
                style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
