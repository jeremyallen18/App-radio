import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/models/attendance.dart';

/// Tarjeta compacta con el resumen de asistencia de un mes: días trabajados,
/// horas totales, tardanzas y faltas, más una mini gráfica de cómo se
/// repartieron los días laborales. Se usa tal cual en el dashboard del
/// empleado (su propio resumen) y del manager (el del departamento).
class AttendanceSummaryCard extends StatelessWidget {
  const AttendanceSummaryCard({
    super.key,
    required this.title,
    required this.summary,
    this.onTap,
  });

  final String title;
  final AttendancePeriodSummary summary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.fingerprint, color: AppColors.accent, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
              ),
              if (onTap != null)
                const Icon(Icons.chevron_right, color: AppColors.textMuted),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _stat('${s.workedDays}', 'días trabajados'),
              _stat(s.totalLabel, 'horas'),
              _stat('${s.lateCount}', 'tardanzas',
                  color: s.lateCount > 0 ? AppColors.warning : null),
              _stat('${s.absentDays}', 'faltas',
                  color: s.absentDays > 0 ? AppColors.error : null),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(height: 90, child: _MonthBreakdownChart(summary: s)),
          if (s.onTimeRate != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text('Puntualidad: ${s.onTimeRate}%',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ],
        ],
      ),
    );
  }

  Widget _stat(String value, String label, {Color? color}) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: TextStyle(
                    color: color ?? AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 18)),
            Text(label,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ],
        ),
      );
}

class _MonthBreakdownChart extends StatelessWidget {
  const _MonthBreakdownChart({required this.summary});
  final AttendancePeriodSummary summary;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final bars = <(String, int, Color)>[
      ('Asist.', s.workedDays, AppColors.success),
      ('Tarde', s.lateCount, AppColors.warning),
      ('Falta', s.absentDays, AppColors.error),
      ('Vac.', s.vacationDays, AppColors.accent),
      ('Incap.', s.incapacityDays, AppColors.brandBlue),
      ('Perm.', s.permissionDays, AppColors.textMuted),
    ];
    final maxY = bars.map((b) => b.$2).fold<int>(1, (a, b) => a > b ? a : b);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY.toDouble() + 1,
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 20,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= bars.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(bars[i].$1,
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 9)),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < bars.length; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: bars[i].$2.toDouble(),
                color: bars[i].$3,
                width: 14,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
              ),
            ]),
        ],
      ),
    );
  }
}
