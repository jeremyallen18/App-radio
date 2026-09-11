import 'package:flutter/material.dart';

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/shared/home/progress/completion_gauge.dart';
import 'package:doliv_social/shared/home/progress/progress_sections.dart';
import 'package:doliv_social/shared/home/progress/progress_stats.dart';
import 'package:doliv_social/shared/home/progress/weekly_rhythm_chart.dart';
import 'package:doliv_social/shared/home/progress_widgets.dart';

/// "Tu progreso" para empleados y managers: medidor de avance, ritmo de la
/// semana, puntualidad y próximas entregas.
class PersonalProgressView extends StatelessWidget {
  const PersonalProgressView({super.key, required this.stats});

  final ProgressStats stats;

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: AppSpacing.xxxl),
        child: EmptyState(
          icon: Icons.query_stats_rounded,
          title: 'Aún no hay tareas asignadas',
          message: 'Cuando tengas tareas, aquí verás tu avance, tu ritmo semanal y tus próximas entregas.',
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(
            title: 'Tu progreso',
            action: LivePulsePill(),
          ),
          AppCard(
            child: Column(
              children: [
                CompletionGauge(
                  done: stats.done,
                  inProgress: stats.inProgress,
                  pending: stats.pending,
                ),
                const SizedBox(height: AppSpacing.lg),
                StatusLegend(
                  done: stats.done,
                  inProgress: stats.inProgress,
                  pending: stats.pending,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CardTitle(
                  title: 'Ritmo de la semana',
                  trailing: '${stats.weekTotal} ${stats.weekTotal == 1 ? 'hecha' : 'hechas'} en 7 días',
                ),
                WeeklyRhythmChart(week: stats.week),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          PunctualityRow(stats: stats),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const CardTitle(title: 'Próximas entregas'),
                UpcomingList(tasks: stats.upcoming),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
