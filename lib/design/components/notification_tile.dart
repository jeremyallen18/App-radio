import 'package:flutter/material.dart';
import 'app_card.dart';
import '../tokens/colors.dart';
import '../tokens/spacing.dart';

/// Tarjeta de notificación: ícono + color por categoría, mensaje, fecha
/// relativa y punto de "no leída". El `type` es el que ya emite el backend
/// (`hive-backend/helpers.php` → `notify_user()`); tipos futuros que no
/// estén en el mapa caen en un ícono/color neutro en vez de romper.
class NotificationTile extends StatelessWidget {
  const NotificationTile({
    super.key,
    required this.type,
    required this.message,
    required this.createdAt,
    required this.unread,
    required this.onTap,
  });

  final String? type;
  final String message;
  final String? createdAt;
  final bool unread;
  final VoidCallback onTap;

  ({IconData icon, Color color, String category}) get _meta {
    switch (type) {
      case 'member_removed':
        return (icon: Icons.person_remove_outlined, color: AppColors.error, category: 'Equipo');
      case 'team_deleted':
        return (icon: Icons.delete_outline, color: AppColors.error, category: 'Equipo');
      case 'leader_assigned':
        return (icon: Icons.shield_outlined, color: AppColors.accent, category: 'Liderazgo');
      case 'department_manager_assigned':
        return (icon: Icons.badge_outlined, color: AppColors.accent, category: 'Departamento');
      case 'department_assigned':
        return (icon: Icons.apartment_outlined, color: AppColors.success, category: 'Departamento');
      default:
        return (icon: Icons.notifications_outlined, color: AppColors.textMuted, category: 'General');
    }
  }

  String get _relativeTime {
    final raw = createdAt;
    if (raw == null || raw.isEmpty) return '';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final diff = DateTime.now().difference(parsed);
    if (diff.inMinutes < 1) return 'Justo ahora';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
    if (diff.inDays < 7) return 'Hace ${diff.inDays} d';
    return '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
  }

  @override
  Widget build(BuildContext context) {
    final meta = _meta;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: meta.color.withValues(alpha: 0.16),
            child: Icon(meta.icon, color: meta.color, size: 18),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      meta.category,
                      style: TextStyle(color: meta.color, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    Text(_relativeTime, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: unread ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          if (unread) ...[
            const SizedBox(width: AppSpacing.sm),
            Container(
              margin: const EdgeInsets.only(top: 4),
              width: 8,
              height: 8,
              decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
            ),
          ],
        ],
      ),
    );
  }
}
