import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/shared/home/progress_widgets.dart';

/// Vista de "Tu progreso" para empleados y managers: dona de tareas
/// completadas vs. pendientes con interacción al tocar cada sección.
class PersonalProgressView extends StatefulWidget {
  const PersonalProgressView({
    super.key,
    required this.completed,
    required this.incomplete,
  });

  final int completed;
  final int incomplete;

  @override
  State<PersonalProgressView> createState() => _PersonalProgressViewState();
}

class _PersonalProgressViewState extends State<PersonalProgressView> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final completed = widget.completed;
    final incomplete = widget.incomplete;
    final total = completed + incomplete;

    if (total == 0) {
      return const Padding(
        padding: EdgeInsets.only(top: AppSpacing.xxxl),
        child: EmptyState(
          icon: Icons.query_stats_rounded,
          title: 'Aún no hay tareas asignadas',
          message: 'Cuando tengas tareas, aquí verás tu progreso.',
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Tu progreso'),
          AppCard(
            child: Column(
              children: [
                AspectRatio(
                  aspectRatio: 1.3,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          sections: _buildSections(completed, incomplete),
                          sectionsSpace: 3,
                          centerSpaceRadius: 64,
                          startDegreeOffset: -90,
                          borderData: FlBorderData(show: false),
                          pieTouchData: PieTouchData(
                            touchCallback: (event, response) {
                              setState(() {
                                if (!event.isInterestedForInteractions ||
                                    response == null ||
                                    response.touchedSection == null) {
                                  _touchedIndex = -1;
                                  return;
                                }
                                _touchedIndex = response
                                    .touchedSection!.touchedSectionIndex;
                              });
                            },
                          ),
                        ),
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOutCubic,
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$total',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 32,
                            ),
                          ),
                          const Text(
                            'tareas',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ProgressLegendDot(
                      color: AppColors.success,
                      label: 'Completadas',
                    ),
                    const SizedBox(width: AppSpacing.xl),
                    ProgressLegendDot(
                      color: AppColors.warning,
                      label: 'Pendientes',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  icon: Icons.check_circle_outline,
                  value: '$completed',
                  label: 'Completadas',
                  accentColor: AppColors.success,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: StatTile(
                  icon: Icons.pending_outlined,
                  value: '$incomplete',
                  label: 'Pendientes',
                  accentColor: AppColors.warning,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildSections(int completed, int incomplete) {
    final total = completed + incomplete;
    final completedPct = completed / total * 100;
    final incompletePct = incomplete / total * 100;

    return [
      PieChartSectionData(
        color: AppColors.success,
        value: completedPct,
        title: '${completedPct.toStringAsFixed(0)}%',
        radius: _touchedIndex == 0 ? 52 : 44,
        titleStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.bgBase,
        ),
      ),
      PieChartSectionData(
        color: AppColors.warning,
        value: incompletePct,
        title: '${incompletePct.toStringAsFixed(0)}%',
        radius: _touchedIndex == 1 ? 52 : 44,
        titleStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.bgBase,
        ),
      ),
    ];
  }
}
