import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/shared/home/progress/progress_stats.dart';

/// Barras de los últimos 7 días: tareas completadas por día, con la parte
/// entregada tarde en ámbar. Hoy va resaltado. Tocar una barra muestra el
/// conteo.
class WeeklyRhythmChart extends StatelessWidget {
  const WeeklyRhythmChart({super.key, required this.week});

  final List<DayCompletion> week;

  static const _weekdayLetters = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

  @override
  Widget build(BuildContext context) {
    final maxY = week.fold<int>(0, (m, d) => d.total > m ? d.total : m);
    final ceiling = (maxY < 3 ? 3 : maxY + 1).toDouble();
    final lastIndex = week.length - 1;

    return SizedBox(
      height: 150,
      child: BarChart(
        BarChartData(
          maxY: ceiling,
          minY: 0,
          alignment: BarChartAlignment.spaceAround,
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 1,
            getDrawingHorizontalLine: (_) => FlLine(
              color: AppColors.surfaceBorder.withValues(alpha: 0.7),
              strokeWidth: 1,
              dashArray: [4, 6],
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: const AxisTitles(),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= week.length) return const SizedBox.shrink();
                  final isToday = i == lastIndex;
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      isToday
                          ? 'Hoy'
                          : _weekdayLetters[week[i].day.weekday - 1],
                      style: TextStyle(
                        color: isToday
                            ? AppColors.accentStrong
                            : AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AppColors.bgBase,
              tooltipBorder: BorderSide(color: AppColors.surfaceBorder),
              tooltipPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              getTooltipItem: (group, _, rod, __) {
                final d = week[group.x];
                final late = d.late > 0 ? ' · ${d.late} tarde' : '';
                return BarTooltipItem(
                  '${d.total} ${d.total == 1 ? 'tarea' : 'tareas'}$late',
                  TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                );
              },
            ),
          ),
          barGroups: [
            for (var i = 0; i < week.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  if (i == lastIndex)
                    // La barra de hoy: sin desglose tarde/a tiempo, con un
                    // degradado emerald→teal que la despega del resto.
                    BarChartRodData(
                      toY: week[i].total.toDouble(),
                      width: 18,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(6)),
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          AppColors.success,
                          const Color(0xFF2DD4BF), // teal-400
                        ],
                      ),
                      backDrawRodData: BackgroundBarChartRodData(
                        show: true,
                        toY: ceiling,
                        color: AppColors.surfaceBorder.withValues(alpha: 0.25),
                      ),
                    )
                  else
                    BarChartRodData(
                      toY: week[i].total.toDouble(),
                      width: 18,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(6)),
                      color: AppColors.success,
                      rodStackItems: [
                        BarChartRodStackItem(
                            0, week[i].onTime.toDouble(), AppColors.success),
                        BarChartRodStackItem(
                          week[i].onTime.toDouble(),
                          week[i].total.toDouble(),
                          AppColors.warning,
                        ),
                      ],
                      backDrawRodData: BackgroundBarChartRodData(
                        show: true,
                        toY: ceiling,
                        color: AppColors.surfaceBorder.withValues(alpha: 0.25),
                      ),
                    ),
                ],
              ),
          ],
        ),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      ),
    );
  }
}
