import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/services/team_service.dart';
import 'package:doliv_social/shared/home/progress_widgets.dart';

/// Vista de "Mi progreso" para el director: el desempeño de tareas de TODOS los
/// departamentos (dona empresa + desglose por área), en vez de su progreso
/// personal, que para él casi siempre está vacío.
class DirectorPerformanceView extends StatelessWidget {
  const DirectorPerformanceView({super.key, required this.data});

  final DeptTasksByDepartment? data;

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
          message:
              'Cuando los departamentos creen y completen tareas, aquí verás '
              'sus gráficas de avance.',
        ),
      );
    }

    // Departamentos con tareas primero; entre ellos, los que tienen más
    // pendientes arriba (los que necesitan seguimiento).
    final rows = [...data.departments]..sort((a, b) {
        final aHas = a.total > 0 ? 0 : 1;
        final bHas = b.total > 0 ? 0 : 1;
        if (aHas != bHas) return aHas - bHas;
        if (b.pending != a.pending) return b.pending - a.pending;
        return a.departmentName
            .toLowerCase()
            .compareTo(b.departmentName.toLowerCase());
      });

    final overallPct = (data.completionRatio * 100).round();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Desempeño por departamento'),
          AppCard(
            child: Column(
              children: [
                AspectRatio(
                  aspectRatio: 1.6,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          sectionsSpace: 3,
                          centerSpaceRadius: 58,
                          startDegreeOffset: -90,
                          borderData: FlBorderData(show: false),
                          sections: [
                            PieChartSectionData(
                              color: AppColors.success,
                              value: data.totalDone.toDouble(),
                              title: '',
                              radius: 42,
                            ),
                            PieChartSectionData(
                              color: AppColors.warning,
                              value: data.totalPending.toDouble(),
                              title: '',
                              radius: 42,
                            ),
                          ],
                        ),
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOutCubic,
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$overallPct%',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 28,
                            ),
                          ),
                          const Text(
                            'completado',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
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
                    ProgressLegendDot(color: AppColors.success, label: 'Completadas'),
                    const SizedBox(width: AppSpacing.xl),
                    ProgressLegendDot(color: AppColors.warning, label: 'Pendientes'),
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
                  value: '${data.totalDone}',
                  label: 'Completadas (empresa)',
                  accentColor: AppColors.success,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: StatTile(
                  icon: Icons.pending_outlined,
                  value: '${data.totalPending}',
                  label: 'Pendientes (empresa)',
                  accentColor: AppColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          const SectionHeader(title: 'Tareas completadas por departamento'),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) const SizedBox(height: AppSpacing.md),
                  _DeptPerformanceRow(counts: rows[i]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Una fila del desglose por departamento en la vista del director: nombre,
/// "hechas/total · %" y una barra de progreso de las tareas completadas.
class _DeptPerformanceRow extends StatelessWidget {
  const _DeptPerformanceRow({required this.counts});

  final DepartmentTaskCounts counts;

  @override
  Widget build(BuildContext context) {
    final bool hasTasks = counts.total > 0;
    final int pct = (counts.completionRatio * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                counts.departmentName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              hasTasks ? '${counts.done}/${counts.total} · $pct%' : 'Sin tareas',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: hasTasks ? counts.completionRatio : 0,
            minHeight: 8,
            backgroundColor: AppColors.surfaceBorder,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.success),
          ),
        ),
        if (hasTasks && counts.pending > 0) ...[
          const SizedBox(height: 4),
          Text(
            '${counts.pending} pendientes',
            style: const TextStyle(color: AppColors.warning, fontSize: 11),
          ),
        ],
      ],
    );
  }
}
