import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/models/calendar_event.dart';
import 'package:doliv_social/models/models.dart';
import 'package:doliv_social/services/calendar_service.dart';
import 'package:doliv_social/core/route_refresh.dart';
import 'package:doliv_social/core/session.dart';
import 'package:doliv_social/core/session_keys.dart' show secureStorage, key;
import 'package:doliv_social/shared/calendar/calendar_tiles.dart';
import 'package:doliv_social/shared/calendar/date_pickers.dart';
import 'package:doliv_social/shared/calendar/event_form_screen.dart';

/// Calendario: actividades a entregar (tareas con fecha límite) y eventos.
///
/// - Empleado: ve solo lo suyo.
/// - Manager: alterna entre "Mi calendario" y "Mi departamento".
/// - Director: "Mi calendario", "Toda la empresa" o un departamento concreto,
///   y puede crear eventos (botón flotante).
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen>
    with RouteAwareRefresh<CalendarScreen> {
  AppRole _role = AppRole.employee;
  List<DepartmentInfo> _departments = [];

  // Selección de alcance. `_scope`: null (propio) | 'department' | 'company'.
  // `_scopeDeptId`: id de departamento concreto (solo director).
  String? _scope;
  String? _scopeDeptId;

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay = DateTime.now();
  CalendarFormat _format = CalendarFormat.month;

  Map<DateTime, List<CalendarActivity>> _activitiesByDay = {};
  Map<DateTime, List<CalendarEvent>> _eventsByDay = {};
  bool _canManage = false;

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void onRouteReenter() {
    if (!_loading) _load();
  }

  Future<void> _bootstrap() async {
    final token = await secureStorage.readSecureData(key);
    final profile = await Session.fetchCurrentUser((token as String?) ?? '');
    if (profile != null) {
      _role = profile.role;
    }
    if (_role == AppRole.director) {
      _departments = await CalendarApi.departments();
    }
    await _load();
  }

  static DateTime _dayKey(DateTime d) => DateTime.utc(d.year, d.month, d.day);

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    // Rango: el mes visible con un margen para los días de meses vecinos.
    final first = DateTime(_focusedDay.year, _focusedDay.month, 1)
        .subtract(const Duration(days: 7));
    final last = DateTime(_focusedDay.year, _focusedDay.month + 1, 0)
        .add(const Duration(days: 7));
    try {
      final feed = await CalendarApi.feed(
        from: first,
        to: last,
        scope: _scopeDeptId != null ? null : _scope,
        departmentId: _scopeDeptId,
      );
      if (!mounted) return;
      final acts = <DateTime, List<CalendarActivity>>{};
      for (final a in feed.activities) {
        if (a.deadline == null) continue;
        acts.putIfAbsent(_dayKey(a.deadline!), () => []).add(a);
      }
      final evs = <DateTime, List<CalendarEvent>>{};
      for (final e in feed.events) {
        evs.putIfAbsent(_dayKey(e.date), () => []).add(e);
      }
      setState(() {
        _activitiesByDay = acts;
        _eventsByDay = evs;
        _canManage = feed.canManage;
        _loading = false;
      });
    } on CalendarException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  List<Object> _markersFor(DateTime day) {
    final k = _dayKey(day);
    return [...?_activitiesByDay[k], ...?_eventsByDay[k]];
  }

  void _setScope({String? scope, String? deptId}) {
    setState(() {
      _scope = scope;
      _scopeDeptId = deptId;
    });
    _load();
  }

  Future<void> _newEvent() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const EventFormScreen()),
    );
    if (created == true) _load();
  }

  Future<void> _editEvent(CalendarEvent event) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EventFormScreen(event: event)),
    );
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedDay ?? _focusedDay;
    final dayActs = _activitiesByDay[_dayKey(selected)] ?? const [];
    final dayEvents = _eventsByDay[_dayKey(selected)] ?? const [];

    return AppScaffold(
      padding: EdgeInsets.zero,
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Calendario'),
      ),
      floatingActionButton: _canManage
          ? FloatingActionButton.extended(
              onPressed: _newEvent,
              icon: const Icon(Icons.add),
              label: const Text('Nuevo evento'),
            )
          : null,
      body: RefreshIndicator(
        color: AppColors.accent,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          children: [
            if (_scopeSelector() != null) ...[
              _scopeSelector()!,
              const SizedBox(height: AppSpacing.md),
            ],
            AppCard(
              child: TableCalendar<Object>(
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
                // Domingo no laboral: se pinta atenuado y no se puede seleccionar.
                weekendDays: kWorkingWeekendDays,
                enabledDayPredicate: tableCalendarWorkingDay,
                selectedDayPredicate: (d) => isSameDay(_selectedDay, d),
                eventLoader: _markersFor,
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
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              ErrorState(message: _error!, onRetry: _load)
            else ...[
              SectionHeader(title: _dayLabel(selected)),
              if (dayActs.isEmpty && dayEvents.isEmpty)
                const EmptyState(
                  icon: Icons.event_available_outlined,
                  title: 'Nada para este día',
                  message: 'No hay actividades ni eventos programados.',
                )
              else ...[
                for (final e in dayEvents) ...[
                  CalendarEventTile(
                    event: e,
                    onEdit: _canManage ? () => _editEvent(e) : null,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                for (final a in dayActs) ...[
                  CalendarActivityTile(activity: a),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
            ],
          ],
        ),
      ),
    );
  }

  String _dayLabel(DateTime d) {
    const meses = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
    ];
    return '${d.day} de ${meses[d.month - 1]} de ${d.year}';
  }

  Widget? _scopeSelector() {
    if (_role == AppRole.manager) {
      return Wrap(
        spacing: AppSpacing.sm,
        children: [
          AppFilterChip(
            label: 'Mi calendario',
            selected: _scope == null,
            onTap: () => _setScope(scope: null),
          ),
          AppFilterChip(
            label: 'Mi departamento',
            selected: _scope == 'department',
            onTap: () => _setScope(scope: 'department'),
          ),
        ],
      );
    }
    if (_role == AppRole.director) {
      return Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          AppFilterChip(
            label: 'Mi calendario',
            selected: _scope == null && _scopeDeptId == null,
            onTap: () => _setScope(scope: null),
          ),
          AppFilterChip(
            label: 'Toda la empresa',
            selected: _scope == 'company',
            onTap: () => _setScope(scope: 'company'),
          ),
          for (final d in _departments)
            AppFilterChip(
              label: d.name,
              selected: _scopeDeptId == d.id,
              onTap: () => _setScope(deptId: d.id),
            ),
        ],
      );
    }
    return null;
  }
}
