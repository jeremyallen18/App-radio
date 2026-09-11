import 'package:flutter/material.dart';

import 'package:doliv_social/design/design.dart';

/// Tarjeta de cabecera del perfil: banda de marca con la foto superpuesta,
/// insignia de estado, nombre + verificación, rol, correo/número de control
/// y los contadores. Sustituye a la antigua cabecera "estilo X" por una sola
/// tarjeta contenida, como en el rediseño.
class ProfileHero extends StatelessWidget {
  const ProfileHero({
    super.key,
    required this.name,
    required this.roleLabel,
    required this.stationLabel,
    required this.photoUrl,
    required this.avatarSeed,
    required this.onEditPhoto,
    required this.uploadingPhoto,
    required this.email,
    required this.onCopyEmail,
    required this.controlNumberLabel,
    required this.stats,
    this.verified = false,
    this.statusBadgeLabel,
    this.trailingBadge,
    this.extraBadges = const [],
    this.onCopyControlNumber,
  });

  final String name;
  final String roleLabel;
  final String stationLabel;
  final String? photoUrl;
  final String avatarSeed;
  final VoidCallback onEditPhoto;
  final bool uploadingPhoto;

  final String email;
  final VoidCallback onCopyEmail;
  final String controlNumberLabel;
  final VoidCallback? onCopyControlNumber;

  final List<Widget> stats;

  final bool verified;
  final String? statusBadgeLabel;
  final Widget? trailingBadge;
  final List<Widget> extraBadges;

  static const double _bandHeight = 92;
  static const double _avatarRadius = 40;
  static const double _ringWidth = 4;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Column(
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
                      colors: [
                        AppColors.brandNavy,
                        AppColors.brandBlue,
                        Color(0xFF10B981), // emerald: cola "en vivo"
                      ],
                      stops: [0.0, 0.6, 1.0],
                    ),
                  ),
                ),
                if (statusBadgeLabel != null)
                  Positioned(
                    top: AppSpacing.sm,
                    right: AppSpacing.sm,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border:
                            Border.all(color: Colors.white.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        statusBadgeLabel!,
                        style: const TextStyle(
                          color: AppColors.onBrand,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ),
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
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.surface,
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [AppColors.brandBlue, Color(0xFF10B981)],
                          ),
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
                            child: Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
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
                          shape: CircleBorder(
                            side: BorderSide(color: AppColors.surfaceBorder),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: uploadingPhoto ? null : onEditPhoto,
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Icon(
                                Icons.photo_camera_outlined,
                                size: 14,
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
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (verified) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.verified_rounded,
                            size: 17, color: AppColors.success),
                      ],
                      if (trailingBadge != null) ...[
                        const Spacer(),
                        trailingBadge!,
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    roleLabel,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accentStrong,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.podcasts_outlined,
                          size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 6),
                      Text(
                        stationLabel,
                        style: TextStyle(
                            fontSize: 13, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                  if (extraBadges.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: extraBadges,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.chip + 4),
                      border: Border.all(color: AppColors.surfaceBorder),
                    ),
                    child: IntrinsicHeight(
                      child: Row(
                        children: [
                          Expanded(
                            child: _InfoCell(
                              icon: Icons.mail_outline,
                              text: email,
                              onCopy: onCopyEmail,
                            ),
                          ),
                          VerticalDivider(
                            width: 1,
                            thickness: 1,
                            color: AppColors.surfaceBorder,
                          ),
                          Expanded(
                            child: _InfoCell(
                              icon: Icons.tag_rounded,
                              text: controlNumberLabel,
                              onCopy: onCopyControlNumber,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      for (int i = 0; i < stats.length; i++) ...[
                        if (i > 0) const SizedBox(width: AppSpacing.sm),
                        Expanded(child: stats[i]),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Celda de dato (ícono + texto truncado + copiar) de la fila
/// correo/número de control de [ProfileHero].
class _InfoCell extends StatelessWidget {
  const _InfoCell({required this.icon, required this.text, this.onCopy});

  final IconData icon;
  final String text;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.textMuted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
            ),
          ),
          if (onCopy != null)
            InkWell(
              onTap: onCopy,
              borderRadius: BorderRadius.circular(AppRadius.chip),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(Icons.copy_rounded,
                    size: 13, color: AppColors.accentStrong),
              ),
            ),
        ],
      ),
    );
  }
}
