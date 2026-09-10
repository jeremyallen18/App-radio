import 'package:flutter/material.dart';

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/models/radio_program.dart';
import 'package:doliv_social/services/radio_service.dart';

/// Parrilla de Radio Doliv: qué programa va a qué hora, por día de la semana.
class RadioScheduleScreen extends StatefulWidget {
  const RadioScheduleScreen({super.key});

  @override
  State<RadioScheduleScreen> createState() => _RadioScheduleScreenState();
}

class _RadioScheduleScreenState extends State<RadioScheduleScreen> {
  static const _dayLabels = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
  static const _dayLong = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo'
  ];

  int _weekday = DateTime.now().weekday; // 1..7
  List<RadioProgram> _all = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await RadioProgramsApi.list();
      if (!mounted) return;
      setState(() {
        _all = items;
        _loading = false;
      });
    } on RadioException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  List<RadioProgram> get _forDay {
    final list = _all.where((p) => p.airsOn(_weekday)).toList();
    list.sort((a, b) => (a.slotStart ?? 99).compareTo(b.slotStart ?? 99));
    return list;
  }

  bool get _isToday => _weekday == DateTime.now().weekday;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Programación'),
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
            child: Row(
              children: [
                for (var d = 1; d <= 7; d++) ...[
                  AppFilterChip(
                    label: _dayLabels[d - 1],
                    selected: _weekday == d,
                    onTap: () => setState(() => _weekday = d),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const LoadingState()
                : _error != null
                    ? ErrorState(message: _error!, onRetry: _load)
                    : RefreshIndicator(
                        color: AppColors.accent,
                        onRefresh: _load,
                        child: _forDay.isEmpty
                            ? ListView(
                                children: const [
                                  Padding(
                                    padding:
                                        EdgeInsets.only(top: AppSpacing.xxl),
                                    child: EmptyState(
                                      icon: Icons.radio_outlined,
                                      title: 'Sin programas este día',
                                      message:
                                          'Prueba con otro día de la semana.',
                                    ),
                                  ),
                                ],
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                    AppSpacing.lg,
                                    AppSpacing.sm,
                                    AppSpacing.lg,
                                    AppSpacing.xxl),
                                itemCount: _forDay.length + 1,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: AppSpacing.sm),
                                itemBuilder: (_, i) {
                                  if (i == 0) {
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 2),
                                      child: Text(
                                        _isToday
                                            ? 'Hoy · ${_dayLong[_weekday - 1]}'
                                            : _dayLong[_weekday - 1],
                                        style: TextStyle(
                                            color: AppColors.textMuted,
                                            fontSize: 12),
                                      ),
                                    );
                                  }
                                  final p = _forDay[i - 1];
                                  return _ProgramTile(
                                    program: p,
                                    onAir: _isToday && p.isOnAirNow(),
                                  );
                                },
                              ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _ProgramTile extends StatelessWidget {
  const _ProgramTile({required this.program, required this.onAir});
  final RadioProgram program;
  final bool onAir;

  @override
  Widget build(BuildContext context) {
    final accent = program.accentColor ?? AppColors.accent;
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 3, height: 44, color: accent),
          const SizedBox(width: AppSpacing.md),
          if (program.imageUrl != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.chip),
              child: Image.network(
                program.imageUrl!,
                width: 44,
                height: 44,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 44,
                  height: 44,
                  color: AppColors.surface,
                  child:
                      Icon(Icons.radio, color: AppColors.textMuted, size: 20),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(program.title,
                          style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 14)),
                    ),
                    if (onAir)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text('AL AIRE',
                            style: TextStyle(
                                color: AppColors.success,
                                fontSize: 10,
                                fontWeight: FontWeight.w800)),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if ((program.timeLabel).isNotEmpty) program.timeLabel,
                    if ((program.host ?? '').isNotEmpty) 'con ${program.host}',
                  ].join(' · '),
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
