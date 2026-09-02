import 'package:flutter/material.dart';
import 'app_badge.dart';
import 'app_card.dart';
import '../tokens/colors.dart';
import '../tokens/spacing.dart';

/// Tarjeta de notificación: ícono + color por categoría, mensaje, fecha
/// relativa y punto de "no leída". El `type` es el que ya emite el backend
/// (`hive-backend/helpers.php` → `notify_user()`); tipos futuros que no
/// estén en el mapa caen en un ícono/color neutro en vez de romper.
///
/// Cuando `extraCount` es mayor que 0 (varios mensajes agrupados de la
/// misma conversación, al estilo WhatsApp) se muestra un badge "+N" junto
/// a la categoría, y `message` debe traer solo la vista previa del más
/// reciente.
class NotificationTile extends StatelessWidget {
  const NotificationTile({
    super.key,
    required this.type,
    required this.message,
    required this.createdAt,
    required this.unread,
    required this.onTap,
    this.extraCount = 0,
    this.onDelete,
  });

  final String? type;
  final String message;
  final String? createdAt;
  final bool unread;
  final VoidCallback onTap;
  final int extraCount;
  final VoidCallback? onDelete;

  ({IconData icon, Color color, String category}) get _meta {
    switch (type) {
      case 'member_removed':
        return (icon: Icons.person_remove_outlined, color: AppColors.error, category: 'Equipo');
      case 'member_resigned':
        return (icon: Icons.exit_to_app_outlined, color: AppColors.error, category: 'Equipo');
      case 'message_received':
        return (icon: Icons.mail_outline, color: AppColors.accent, category: 'Mensaje');
      case 'member_added':
        return (icon: Icons.person_add_alt_1_outlined, color: AppColors.success, category: 'Equipo');
      case 'team_deleted':
        return (icon: Icons.delete_outline, color: AppColors.error, category: 'Equipo');
      // Notificación antigua (tarea asignada, alta de miembro, etc.) cuyo
      // equipo fue eliminado después: el backend le reemplaza el mensaje
      // por un aviso genérico (ver deleteTeam() en hive-backend/index.php)
      // porque el contenido original ya no existe.
      case 'team_content_removed':
        return (icon: Icons.group_off_outlined, color: AppColors.textMuted, category: 'Equipo');
      case 'leader_assigned':
      case 'admin_added':
        return (icon: Icons.shield_outlined, color: AppColors.accent, category: 'Administración');
      case 'admin_removed':
        return (icon: Icons.remove_moderator_outlined, color: AppColors.textMuted, category: 'Administración');
      case 'department_manager_assigned':
        return (icon: Icons.badge_outlined, color: AppColors.accent, category: 'Departamento');
      case 'department_assigned':
        return (icon: Icons.apartment_outlined, color: AppColors.success, category: 'Departamento');
      // Workflow jerárquico de tareas (Director -> Departamento -> Manager
      // -> Empleado), emitidos desde hive-backend/index.php.
      case 'task_assigned':
        return (icon: Icons.assignment_outlined, color: AppColors.accent, category: 'Tarea');
      case 'task_completed':
        return (icon: Icons.task_alt_outlined, color: AppColors.warning, category: 'Tarea');
      case 'task_approved':
        return (icon: Icons.verified_outlined, color: AppColors.success, category: 'Tarea');
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
    // Pasadas las 24 horas se muestra la fecha exacta en la que se asignó
    // (dd/mm/aaaa) en vez de seguir contando "Hace X días".
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
                    if (extraCount > 0) ...[
                      const SizedBox(width: AppSpacing.sm),
                      AppBadge(label: '+$extraCount', variant: AppBadgeVariant.info),
                    ],
                    const Spacer(),
                    Text(_relativeTime, style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: unread ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
                if (extraCount > 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    '+$extraCount mensaje${extraCount == 1 ? '' : 's'} sin leer',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          if (unread) ...[
            const SizedBox(width: AppSpacing.sm),
            Container(
              margin: const EdgeInsets.only(top: 4),
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
            ),
          ],
          if (onDelete != null) ...[
            const SizedBox(width: AppSpacing.xs),
            IconButton(
              icon: Icon(Icons.delete_outline, size: 20, color: AppColors.textMuted),
              tooltip: 'Eliminar notificación',
              onPressed: onDelete,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ],
      ),
    );
  }
}
