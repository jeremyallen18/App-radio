import 'package:flutter/material.dart';

import 'package:doliv_social/design/tokens/colors.dart';
import 'package:doliv_social/design/tokens/spacing.dart';
import 'package:doliv_social/design/components/app_card.dart';
import 'package:doliv_social/design/components/identity_avatar.dart';

/// Fila de una persona en un listado (directorio de compañeros, miembros de
/// un equipo): foto, nombre, puesto y, opcionalmente, una insignia a la
/// derecha. Toca la fila entera para abrir su ficha.
class PersonCard extends StatelessWidget {
  const PersonCard({
    super.key,
    required this.name,
    required this.headline,
    this.photoUrl,
    this.avatarSeed,
    this.subtitle,
    this.badge,
    this.onTap,
  });

  final String name;

  /// Puesto o rol: la línea que explica qué hace esta persona.
  final String headline;
  final String? photoUrl;
  final String? avatarSeed;

  /// Tercera línea opcional (departamento, correo…).
  final String? subtitle;

  /// Insignia a la derecha del nombre, p. ej. el rol o un "Tú".
  final Widget? badge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: onTap,
      child: Row(
        children: [
          IdentityAvatar(
            id: avatarSeed ?? name,
            label: name,
            radius: 24,
            photoUrl: photoUrl,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: AppSpacing.sm),
                      badge!,
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  headline,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: AppSpacing.sm),
            Icon(Icons.chevron_right, size: 20, color: AppColors.textMuted),
          ],
        ],
      ),
    );
  }
}
