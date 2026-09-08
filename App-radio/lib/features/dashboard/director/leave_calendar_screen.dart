import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/models/leave_request.dart';
import 'package:doliv_social/models/models.dart';
import 'package:doliv_social/services/leave_service.dart';
import 'package:doliv_social/services/team_service.dart';
import 'package:doliv_social/shared/calendar/date_pickers.dart';

/// Calendario de ausencias del equipo (solo director). Muestra en qué días
/// hay gente de permiso, vacaciones o incapacidad, para no dejar un área
/// descubierta al aprobar una nueva solicitud.
class LeaveCalendarScreen extends StatefulWidget {
  const LeaveCalendarScreen({super.key});

  @override
  State<LeaveCalendarScreen> createState() => _LeaveCalendarScreenState();
}

class _LeaveCalendarScreenState extends State<LeaveCalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay = DateTime.now();
  CalendarFormat _format = CalendarFormat.month;

  List<DepartmentInfo> _departments = const [];
  String? _departmentId;

  List<LeaveCalendarItem> _items = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      _departments = await TeamApi.listDepartments();
    } catch (_) {
      _departments = const [];
    }
    await _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    // Rango visible: el mes enfocado con un colchón de una semana a cada lado.
    final first = DateTime(_focusedDay.year, _focusedDay.month, 1)
        .subtract(const Duration(days: 7));
    final last = DateTime(_focusedDay.year, _focusedDay.month + 1, 0)
        .add(const Duration(days: 7));
    try {
      final items = await LeaveApi.calendar(
        from: first,
        to: last,
        departmentId: _departmentId,
      );
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } on LeaveException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  List<LeaveCalendarItem> _forDay(DateTime day) =>
      _items.where((i) => i.coversDay(day)).toList();

  Color _colorFor(LeaveCalendarItem i) {
    if (i.status == LeaveStatus.pendiente) return AppColors.textMuted;
    return switch (i.type) {
      LeaveType.vacaciones => AppColors.accent,
      LeaveType.incapacidad => AppColors.error,
      LeaveType.permiso => AppColors.brandBlue,
    };
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedDay ?? _focusedDay;
    final dayItems = _forDay(selected);

    return AppScaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Ausencias del equipo'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xxl),
        children: [
          if (_departments.isNotEmpty)
            DropdownButtonFormField<String?>(
              initialValue: _departmentId,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.groups_2_outlined, color: AppColors.accent),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem(
                    value: null, child: Text('Todos los departamentos')),
                for (final d in _departments)
                  DropdownMenuItem(value: d.id, child: Text(d.name)),
              ],
              onChanged: (v) {
                setState(() => _departmentId = v);
                _load();
              },
            ),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            child: TableCalendar<LeaveCalendarItem>(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2035, 12, 31),
              focusedDay: _focusedDay,
              locale: kCalendarLocale,
              calendarFormat: _format,
              availableCalendarFormats: const {
                CalendarFormat.month: 'Mes',
                CalendarFormat.twoWeeks: '2 semanas',
                CalendarFormat.week: 'Semana',
              },
              startingDayOfWeek: StartingDayOfWeek.monday,
              weekendDays: kWorkingWeekendDays,
              enabledDayPredicate: tableCalendarWorkingDay,
              selectedDayPredicate: (d) => isSameDay(_selectedDay, d),
              eventLoader: _forDay,
              onDaySelected: (sel, foc) {
                if (!isWorkingDay(sel)) return;
                setState(() {
                  _selectedDay = sel;
                  _focusedDay = foc;
                });
              },
              onFormatChanged: (f) => setState(() => _format = f),
              onPageChanged: (foc) {
                _focusedDay = foc;
                _load();
              },
              calendarStyle: const CalendarStyle(
                markersMaxCount: 4,
                markerDecoration: BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                ),
                todayDecoration: BoxDecoration(
                  color: AppColors.brandBlue,
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                ),
              ),
              calendarBuilders: CalendarBuilders(
                markerBuilder: (context, day, items) {
                  if (items.isEmpty) return null;
                  return Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final i in items.take(4))
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            decoration: BoxDecoration(
                              color: _colorFor(i),
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_loading)
            const Padding(
                padding: EdgeInsets.all(AppSpacing.xl), child: LoadingState())
          else if (_error != null)
            ErrorState(message: _error!, onRetry: _load)
          else ...[
            SectionHeader(title: _dayLabel(selected)),
            const SizedBox(height: AppSpacing.sm),
            if (dayItems.isEmpty)
              const EmptyState(
                icon: Icons.event_available_outlined,
                title: 'Nadie ausente este día',
              )
            else
              for (final i in dayItems) ...[
                _AbsenceTile(item: i, color: _colorFor(i)),
                const SizedBox(height: AppSpacing.sm),
              ],
          ],
        ],
      ),
    );
  }

  String _dayLabel(DateTime d) {
    const dias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    return '${dias[d.weekday - 1]} ${d.day}/${d.month}/${d.year}';
  }
}

class _AbsenceTile extends StatelessWidget {
  const _AbsenceTile({required this.item, required this.color});
  final LeaveCalendarItem item;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Icon(item.type.icon, color: color, size: 20),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.employeeName ?? 'Empleado',
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
                Text(
                  '${item.typeLabel} · ${item.rangeLabel}'
                  '${item.departmentName != null ? ' · ${item.departmentName}' : ''}',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          if (item.status == LeaveStatus.pendiente)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.textMuted.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: const Text('Pendiente',
                  style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }
}
