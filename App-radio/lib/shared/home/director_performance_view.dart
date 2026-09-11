import 'package:flutter/material.dart';

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/services/team_service.dart';
import 'package:doliv_social/shared/home/progress/completion_gauge.dart';
import 'package:doliv_social/shared/home/progress/department_stack_bars.dart';
import 'package:doliv_social/shared/home/progress/progress_sections.dart';
import 'package:doliv_social/shared/home/progress/progress_stats.dart';
import 'package:doliv_social/shared/home/progress/weekly_rhythm_chart.dart';
import 'package:doliv_social/shared/home/progress_widgets.dart';
import 'package:doliv_social/shared/teams/task_board_screen.dart';

/// "Desempeño por departamento" para el director: medidor de la empresa,
/// barras apiladas por área (tocar abre su tablero) y ritmo semanal de toda
/// la empresa cuando el listado completo está disponible.
class DirectorPerformanceView extends StatelessWidget {
  const DirectorPerformanceView({
    super.key,
    required this.data,
    this.companyStats,
  });

  final DeptTasksByDepartment? data;

  /// Calculado con `GET /dept-tasks` sin filtro (todas las áreas). `null`
  /// si esa llamada falló: se omite la tarjeta de ritmo, no la pantalla.
  final ProgressStats? companyStats;

  @override
  Widget build(BuildContext context) {
    final data = this.data;
    if (data == null || data.departments.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: AppSpacing.xxxl),
        child: EmptyState(
          icon: Icons.insights_outlined,
          title: 'Todavía no hay departamentos',
          message: 'Crea equipos para ver aquí su avance de tareas.',
        ),
      );
    }
    if (data.total == 0) {
      return const Padding(
        padding: EdgeInsets.only(top: AppSpacing.xxxl),
        child: EmptyState(
          icon: Icons.query_stats_rounded,
          title: 'Aún no hay tareas registradas',
          message: 'Cuando los departamentos creen y completen tareas, aquí verás sus gráficas de avance.',
        ),
      );
    }

    // Con tareas primero; entre ellos, mayor avance arriba y, a igual
    // avance, más pendientes arriba (los que necesitan seguimiento).
    final rows = [...data.departments]..sort((a, b) {
        final aHas = a.total > 0 ? 0 : 1;
        final bHas = b.total > 0 ? 0 : 1;
        if (aHas != bHas) return aHas - bHas;
        final byRatio = b.completionRatio.compareTo(a.completionRatio);
        if (byRatio != 0) return byRatio;
        if (b.pending != a.pending) return b.pending - a.pending;
        return a.departmentName.toLowerCase().compareTo(b.departmentName.toLowerCase());
      });

    final company = companyStats;
    final active = data.departments.where((d) => d.total > 0).length;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(
            title: 'Desempeño de la empresa',
            action: LivePulsePill(),
          ),
          AppCard(
            child: Column(
              children: [
                CompletionGauge(
                  done: data.totalDone,
                  inProgress: data.totalInProgress,
                  pending: data.totalNotStarted,
                ),
                const SizedBox(height: AppSpacing.lg),
                StatusLegend(
                  done: data.totalDone,
                  inProgress: data.totalInProgress,
                  pending: data.totalNotStarted,
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
                  title: 'Por departamento',
                  trailing: '$active de ${data.departments.length} con tareas',
                ),
                DepartmentStackBars(
                  rows: rows,
                  onOpen: (d) => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TaskBoardScreen(
                        departmentId: d.departmentId,
                        departmentName: d.departmentName,
                        canManage: true,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (company != null) ...[
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CardTitle(
                    title: 'Ritmo de la empresa',
                    trailing: '${company.weekTotal} ${company.weekTotal == 1 ? 'hecha' : 'hechas'} en 7 días',
                  ),
                  WeeklyRhythmChart(week: company.week),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            PunctualityRow(stats: company),
          ],
        ],
      ),
    );
  }
}
