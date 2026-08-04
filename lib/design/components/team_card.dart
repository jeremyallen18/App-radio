import 'package:flutter/material.dart';
import 'app_card.dart';
import 'identity_avatar.dart';
import '../tokens/colors.dart';
import '../tokens/spacing.dart';

/// Tarjeta de equipo: avatar con inicial, nombre + código, conteo de
/// miembros/tareas y barra de avance. Todos los números que recibe deben
/// salir de datos reales del backend (`GET /team/showTeams`) — este widget
/// es puramente presentacional, no hace fetch.
class TeamCard extends StatelessWidget {
  const TeamCard({
    super.key,
    required this.teamName,
    required this.teamCode,
    required this.memberCount,
    required this.pendingCount,
    required this.completedCount,
    required this.accentColor,
    required this.onTap,
  });

  final String teamName;
  final String teamCode;
  final int memberCount;
  final int pendingCount;
  final int completedCount;
  final Color accentColor;
  final VoidCallback onTap;

  /// Misma paleta determinística que usan los avatares del chat
  /// ([IdentityAvatar]) — un solo lugar define "id → color" para toda la app.
  static Color colorForId(String id) {
    return IdentityAvatar.colorForId(id);
  }

  int get _totalTasks => pendingCount + completedCount;

  double get _completionRatio => _totalTasks == 0 ? 0 : completedCount / _totalTasks;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: accentColor.withValues(alpha: 0.16),
                child: Text(
                  teamName.isNotEmpty ? teamName[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      teamName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Código: $teamCode',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textMuted),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _statChip(Icons.people_outline, '$memberCount miembros'),
              const SizedBox(width: AppSpacing.sm),
              _statChip(Icons.pending_actions, '$pendingCount pendientes', color: AppColors.warning),
              const SizedBox(width: AppSpacing.sm),
              _statChip(Icons.check_circle_outline, '$completedCount hechas', color: AppColors.success),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (_totalTasks == 0)
            const Text(
              'Sin tareas todavía',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                  child: LinearProgressIndicator(
                    value: _completionRatio,
                    minHeight: 6,
                    backgroundColor: AppColors.surfaceBorder,
                    valueColor: AlwaysStoppedAnimation(accentColor),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${(_completionRatio * 100).round()}% completado',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _statChip(IconData icon, String label, {Color color = AppColors.textMuted}) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
