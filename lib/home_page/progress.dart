import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:doliv_social/models/appbar.dart';
import 'package:doliv_social/home_page/tasks.dart';
import '../design/design.dart';

class ProgressChart extends StatefulWidget {
  const ProgressChart({Key? key}) : super(key: key);

  @override
  State<ProgressChart> createState() => _ProgressChartState();
}

class _ProgressChartState extends State<ProgressChart> {
  int _touchedIndex = -1;
  late Future<void> _countsFuture;

  @override
  void initState() {
    super.initState();
    _countsFuture = refreshTaskCounts();
  }

  Future<void> _reload() {
    final future = refreshTaskCounts();
    setState(() => _countsFuture = future);
    return future;
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: MyAppBar(),
      scrollable: true,
      body: FutureBuilder<void>(
        future: _countsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.only(top: AppSpacing.xxxl),
              child: LoadingState(message: 'Cargando tu progreso...'),
            );
          }

          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xxxl),
              child: ErrorState(onRetry: _reload),
            );
          }

          return _buildContent();
        },
      ),
    );
  }

  Widget _buildContent() {
    final completed = completedTaskNum ?? 0;
    final incomplete = incompleteTaskNum ?? 0;
    final total = completed + incomplete;

    return total == 0
        ? const Padding(
            padding: EdgeInsets.only(top: AppSpacing.xxxl),
            child: EmptyState(
              icon: Icons.query_stats_rounded,
              title: 'Aún no hay tareas asignadas',
              message: 'Cuando tengas tareas, aquí verás tu progreso.',
            ),
          )
        : Padding(
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
                          _LegendDot(
                            color: AppColors.success,
                            label: 'Completadas',
                          ),
                          const SizedBox(width: AppSpacing.xl),
                          _LegendDot(
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

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          label,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
      ],
    );
  }
}
