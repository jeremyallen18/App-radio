import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/models/models.dart';
import 'package:doliv_social/models/calendar_event.dart';
import 'package:doliv_social/services/calendar_service.dart';
import 'package:doliv_social/core/api_config.dart';
import 'package:doliv_social/core/session_keys.dart' show secureStorage, key;
import 'package:doliv_social/shared/calendar/location_picker_map.dart';
import 'package:doliv_social/shared/calendar/date_pickers.dart';

/// Formulario para que el DIRECTOR cree o EDITE un evento del calendario.
///
/// Un evento es `General` (toda la empresa) o de `Áreas específicas`. Al
/// activar "Con ubicación" se exige elegir área(s), un punto en el mapa, un
/// radio y una hora de entrada: ese día, para los miembros de esas áreas, la
/// entrada de asistencia se registra en el lugar y a la hora del evento.
///
/// Si se pasa [event], el formulario entra en modo edición: precarga los
/// datos y guarda contra `POST /events/{id}` (no crea uno nuevo).
class EventFormScreen extends StatefulWidget {
  const EventFormScreen({super.key, this.event});

  final CalendarEvent? event;

  @override
  State<EventFormScreen> createState() => _EventFormScreenState();
}

const List<int> _kReminderChoices = [7, 5, 3, 2];

class _EventFormScreenState extends State<EventFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _label = TextEditingController();
  final _locationText = TextEditingController();

  DateTime? _date;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  bool _byAreas = false;
  final Set<String> _selectedAreas = {};
  List<DepartmentInfo> _departments = [];
  bool _loadingDepts = false;

  bool _hasLocation = false;
  double? _lat;
  double? _lng;
  double _radiusM = 50;
  TimeOfDay? _entryTime;
  final Set<int> _reminderOffsets = {..._kReminderChoices};

  bool _saving = false;

  bool get _isEditing => widget.event != null;

  @override
  void initState() {
    super.initState();
    final e = widget.event;
    if (e != null) {
      _title.text = e.title;
      _description.text = e.description ?? '';
      _label.text = e.locationLabel ?? '';
      _locationText.text = e.locationText ?? '';
      _date = e.date;
      _startTime = _parseTime(e.startTime);
      _endTime = _parseTime(e.endTime);
      _byAreas = e.scope == 'areas';
      _selectedAreas.addAll(e.areas.map((a) => a.id));
      _hasLocation = e.hasLocation;
      _lat = e.latitude;
      _lng = e.longitude;
      _radiusM = (e.radiusM ?? 50).toDouble();
      _entryTime = _parseTime(e.entryTime);
      // Sincroniza siempre con el evento: una lista vacía es una elección
      // válida del director ("sin recordatorios"), no un "usa el default".
      _reminderOffsets
        ..clear()
        ..addAll(e.reminderOffsets.where(_kReminderChoices.contains));
      if (_byAreas) _loadDepartments();
    }
  }

  static TimeOfDay? _parseTime(String? hhmm) {
    if (hhmm == null || !hhmm.contains(':')) return null;
    final parts = hhmm.split(':');
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _label.dispose();
    _locationText.dispose();
    super.dispose();
  }

  Future<void> _loadDepartments() async {
    if (_departments.isNotEmpty || _loadingDepts) return;
    setState(() => _loadingDepts = true);
    try {
      final token = await secureStorage.readSecureData(key);
      final res = await http.get(
        Uri.parse('$kBaseUrl/department/list'),
        headers: {'Authorization': (token as String?) ?? ''},
      );
      if (res.statusCode == 200) {
        final List<dynamic> raw = jsonDecode(res.body)['departments'] ?? [];
        setState(() {
          _departments = raw
              .map((d) => DepartmentInfo.fromJson(Map<String, dynamic>.from(d)))
              .toList();
        });
      }
    } catch (_) {
      // sin red: se deja la lista vacía y el guardado avisará.
    } finally {
      if (mounted) setState(() => _loadingDepts = false);
    }
  }

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await pickWorkingDate(
      context,
      initialDate: _date ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime(
      void Function(TimeOfDay) onPicked, TimeOfDay? initial) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: initial ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null) setState(() => onPicked(picked));
  }

  Future<void> _pickLocation() async {
    final result = await Navigator.of(context).push<({double lat, double lng})>(
      MaterialPageRoute(
        builder: (_) =>
            LocationPickerMap(initialLatitude: _lat, initialLongitude: _lng),
      ),
    );
    if (result != null) {
      setState(() {
        _lat = result.lat;
        _lng = result.lng;
      });
    }
  }

  String? _validate() {
    if (_date == null) return 'Elige la fecha del evento.';
    if (_byAreas && _selectedAreas.isEmpty) {
      return 'Selecciona al menos un área para un evento por áreas.';
    }
    if (_startTime != null && _endTime != null) {
      final s = _startTime!.hour * 60 + _startTime!.minute;
      final e = _endTime!.hour * 60 + _endTime!.minute;
      if (e < s) return 'La hora de fin no puede ser antes de la de inicio.';
    }
    if (_hasLocation) {
      if (!_byAreas || _selectedAreas.isEmpty) {
        return 'Un evento con ubicación debe tener áreas asignadas.';
      }
      if (_lat == null || _lng == null) {
        return 'Marca la ubicación del evento en el mapa.';
      }
      if (_entryTime == null) return 'Indica la hora de entrada del evento.';
    }
    return null;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final err = _validate();
    if (err != null) {
      _snack(err);
      return;
    }

    setState(() => _saving = true);
    final body = <String, dynamic>{
      'title': _title.text.trim(),
      'date': _fmtDate(_date!),
      'description': _description.text.trim(),
      'scope': _byAreas ? 'areas' : 'general',
      'locationText': _locationText.text.trim(),
      'reminderOffsets':
          (_reminderOffsets.toList()..sort((a, b) => b - a)).join(','),
      if (_startTime != null) 'startTime': _fmtTime(_startTime!),
      if (_endTime != null) 'endTime': _fmtTime(_endTime!),
      if (_byAreas) 'areas': _selectedAreas.toList(),
      'hasLocation': _hasLocation,
      if (_hasLocation) ...{
        'latitude': _lat,
        'longitude': _lng,
        'radiusM': _radiusM.round(),
        'locationLabel': _label.text.trim(),
        'entryTime': _fmtTime(_entryTime!),
      },
    };

    try {
      if (_isEditing) {
        await CalendarApi.updateEvent(widget.event!.id, body);
      } else {
        await CalendarApi.createEvent(body);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on CalendarException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack(e.message);
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      padding: EdgeInsets.zero,
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(_isEditing ? 'Editar evento' : 'Nuevo evento'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          children: [
            AppTextField(
              controller: _title,
              hintText: 'Título del evento',
              prefixIcon: const Icon(Icons.event_outlined),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Escribe un título.' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _description,
              hintText: 'Descripción (opcional)',
              maxLines: 3,
              prefixIcon: const Icon(Icons.notes_outlined),
            ),
            const SizedBox(height: AppSpacing.md),
            _PickerRow(
              icon: Icons.calendar_today_outlined,
              label: 'Fecha',
              value: _date != null ? _fmtDate(_date!) : 'Elegir fecha',
              onTap: _pickDate,
            ),
            _PickerRow(
              icon: Icons.schedule,
              label: 'Hora de inicio (opcional)',
              value: _startTime != null ? _fmtTime(_startTime!) : '—',
              onTap: () => _pickTime((t) => _startTime = t, _startTime),
            ),
            _PickerRow(
              icon: Icons.schedule_outlined,
              label: 'Hora de fin (opcional)',
              value: _endTime != null ? _fmtTime(_endTime!) : '—',
              onTap: () => _pickTime((t) => _endTime = t, _endTime),
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _locationText,
              hintText: 'Lugar (opcional)',
              prefixIcon: const Icon(Icons.place_outlined),
              validator: (v) => (v != null && v.trim().length > 255)
                  ? 'El lugar es demasiado largo (máx. 255).'
                  : null,
            ),
            const SizedBox(height: AppSpacing.xl),
            const SectionHeader(title: 'Recordatorios'),
            Text(
              'Se avisará a la audiencia estos días antes del evento.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final d in _kReminderChoices)
                  AppFilterChip(
                    label: '$d días',
                    selected: _reminderOffsets.contains(d),
                    onTap: () => setState(() {
                      if (!_reminderOffsets.remove(d)) _reminderOffsets.add(d);
                    }),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            const SectionHeader(title: 'Alcance'),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                AppFilterChip(
                  label: 'General (toda la empresa)',
                  selected: !_byAreas,
                  onTap: () => setState(() {
                    _byAreas = false;
                    _hasLocation = false;
                  }),
                ),
                AppFilterChip(
                  label: 'Áreas específicas',
                  selected: _byAreas,
                  onTap: () {
                    setState(() => _byAreas = true);
                    _loadDepartments();
                  },
                ),
              ],
            ),
            if (_byAreas) ...[
              const SizedBox(height: AppSpacing.md),
              if (_loadingDepts)
                const Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_departments.isEmpty)
                Text(
                  'No se pudieron cargar los departamentos. Revisa la conexión.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                )
              else
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final d in _departments)
                      AppFilterChip(
                        label: d.name,
                        selected: _selectedAreas.contains(d.id),
                        onTap: () => setState(() {
                          if (!_selectedAreas.remove(d.id)) {
                            _selectedAreas.add(d.id);
                          }
                        }),
                      ),
                  ],
                ),
            ],
            const SizedBox(height: AppSpacing.xl),
            const SectionHeader(title: 'Ubicación'),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Con ubicación',
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'Cambia el lugar y la hora de entrada de las áreas asignadas '
                      'solo ese día. Las áreas no incluidas siguen igual.',
                      style:
                          TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                    value: _hasLocation,
                    onChanged: _byAreas
                        ? (v) => setState(() => _hasLocation = v)
                        : null,
                  ),
                  if (!_byAreas)
                    Text(
                      'Primero elige "Áreas específicas" para poder añadir ubicación.',
                      style: TextStyle(color: AppColors.warning, fontSize: 12),
                    ),
                  if (_hasLocation) ...[
                    Divider(
                        color: AppColors.surfaceBorder, height: AppSpacing.xl),
                    _PickerRow(
                      icon: Icons.map_outlined,
                      label: 'Punto en el mapa',
                      value: (_lat != null && _lng != null)
                          ? '${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}'
                          : 'Elegir en el mapa',
                      onTap: _pickLocation,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Radio permitido: ${_radiusM.round()} m',
                      style:
                          TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                    Slider(
                      value: _radiusM,
                      min: 5,
                      max: 1000,
                      divisions: 199,
                      label: '${_radiusM.round()} m',
                      onChanged: (v) => setState(() => _radiusM = v),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppTextField(
                      controller: _label,
                      hintText: 'Nombre del lugar (opcional)',
                      prefixIcon: const Icon(Icons.place_outlined),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _PickerRow(
                      icon: Icons.login,
                      label: 'Hora de entrada del evento',
                      value: _entryTime != null
                          ? _fmtTime(_entryTime!)
                          : 'Elegir hora',
                      onTap: () => _pickTime((t) => _entryTime = t, _entryTime),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: _isEditing ? 'Guardar cambios' : 'Crear evento',
              loading: _saving,
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}

class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            Icon(icon, color: AppColors.accent, size: 20),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                label,
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                  color: AppColors.textPrimary, fontWeight: FontWeight.w600),
            ),
            Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
