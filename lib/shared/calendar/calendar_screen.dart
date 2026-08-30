import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:table_calendar/table_calendar.dart';

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/models/calendar_event.dart';
import 'package:doliv_social/models/models.dart';
import 'package:doliv_social/services/calendar_service.dart';
import 'package:doliv_social/core/api_config.dart';
import 'package:doliv_social/core/session.dart';
import 'package:doliv_social/core/session_keys.dart' show secureStorage, key;
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

class _CalendarScreenState extends State<CalendarScreen> {
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

  Future<void> _bootstrap() async {
    final token = await secureStorage.readSecureData(key);
    final profile = await Session.fetchCurrentUser((token as String?) ?? '');
    if (profile != null) {
      _role = profile.role;
    }
    if (_role == AppRole.director) {
      await _loadDepartments(token);
    }
    await _load();
  }

  Future<void> _loadDepartments(dynamic token) async {
    try {
      final res = await http.get(
        Uri.parse('$kBaseUrl/department/list'),
        headers: {'Authorization': (token as String?) ?? ''},
      );
      if (res.statusCode == 200) {
        final List<dynamic> raw = jsonDecode(res.body)['departments'] ?? [];
        _departments = raw
            .map((d) => DepartmentInfo.fromJson(Map<String, dynamic>.from(d)))
            .toList();
      }
    } catch (_) {}
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

  @override
  Widget build(BuildContext context) {
    final selected = _selectedDay ?? _focusedDay;
    final dayActs = _activitiesByDay[_dayKey(selected)] ?? const [];
    final dayEvents = _eventsByDay[_dayKey(selected)] ?? const [];

    return AppScaffold(
      padding: EdgeInsets.zero,
      appBar: AppBar(
        leading: const AppBackButton(),
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
                calendarFormat: _format,
                availableCalendarFormats: const {
                  CalendarFormat.month: 'Mes',
                  CalendarFormat.twoWeeks: '2 semanas',
                  CalendarFormat.week: 'Semana',
                },
                startingDayOfWeek: StartingDayOfWeek.monday,
                selectedDayPredicate: (d) => isSameDay(_selectedDay, d),
                eventLoader: _markersFor,
                onDaySelected: (sel, foc) => setState(() {
                  _selectedDay = sel;
                  _focusedDay = foc;
                }),
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
                  _EventTile(event: e),
                  const SizedBox(height: AppSpacing.sm),
                ],
                for (final a in dayActs) ...[
                  _ActivityTile(activity: a),
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

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event});
  final CalendarEvent event;

  @override
  Widget build(BuildContext context) {
    final timeLabel = [
      if (event.startTime != null) event.startTime!,
      if (event.endTime != null) '– ${event.endTime!}',
    ].join(' ');
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.event, color: AppColors.accent, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  event.title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              if (event.hasLocation)
                const AppBadge(label: 'Con ubicación', variant: AppBadgeVariant.info),
            ],
          ),
          if (timeLabel.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(timeLabel, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ],
          if ((event.description ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(event.description!, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ],
          const SizedBox(height: 6),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: 4,
            children: [
              AppBadge(label: event.isGeneral ? 'General' : 'Áreas'),
              if (!event.isGeneral && event.areaNames.isNotEmpty)
                AppBadge(label: event.areaNames),
              if (event.hasLocation && event.entryTime != null)
                AppBadge(
                  label: 'Entrada ${event.entryTime}'
                      '${(event.locationLabel ?? '').isNotEmpty ? ' · ${event.locationLabel}' : ''}',
                  variant: AppBadgeVariant.warning,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.activity});
  final CalendarActivity activity;

  @override
  Widget build(BuildContext context) {
    final sub = [
      if ((activity.teamName ?? '').isNotEmpty) activity.teamName!,
      if ((activity.domainName ?? '').isNotEmpty) activity.domainName!,
    ].join(' · ');
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            activity.completed ? Icons.check_circle : Icons.assignment_outlined,
            color: activity.completed ? AppColors.success : AppColors.warning,
            size: 18,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.description,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    decoration: activity.completed ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (sub.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(sub, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ],
                if ((activity.assignedTo).isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    activity.assignedTo,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          AppBadge(
            label: activity.completed ? 'Entregada' : 'A entregar',
            variant: activity.completed ? AppBadgeVariant.success : AppBadgeVariant.warning,
          ),
        ],
      ),
    );
  }
}
