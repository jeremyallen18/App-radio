import 'package:flutter/material.dart';

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/models/models.dart';
import 'package:doliv_social/models/internal_announcement.dart';
import 'package:doliv_social/services/internal_announcement_service.dart';
import 'package:doliv_social/services/team_service.dart';
import 'package:doliv_social/shared/calendar/date_pickers.dart';

/// Formulario para que el DIRECTOR publique o edite un anuncio interno.
///
/// El anuncio se recibe de inmediato al publicarlo (no hay ventana de
/// vigencia). Reglas (validadas también en `ia_body_or_fail`):
///  - Alcance `General` (toda la empresa) o `Áreas específicas` (departamentos).
///  - Si "pide confirmación de asistencia", se puede añadir fecha/hora y lugar
///    de la reunión; el resto responderá sí / no y, quien confirme "sí",
///    recibirá recordatorios recurrentes hasta la reunión.
class InternalAnnouncementFormScreen extends StatefulWidget {
  const InternalAnnouncementFormScreen({super.key, this.existing});

  final InternalAnnouncement? existing;

  bool get isEditing => existing != null;

  @override
  State<InternalAnnouncementFormScreen> createState() =>
      _InternalAnnouncementFormScreenState();
}

class _InternalAnnouncementFormScreenState
    extends State<InternalAnnouncementFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _location = TextEditingController();

  bool _byAreas = false;
  final Set<String> _selectedAreas = {};
  List<DepartmentInfo> _departments = [];
  bool _loadingDepts = false;

  bool _requiresConfirmation = false;
  DateTime? _eventDate;
  TimeOfDay? _eventTime;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _title.text = e.title;
      _body.text = e.body;
      _location.text = e.locationLabel ?? '';
      _byAreas = !e.isGeneral;
      _selectedAreas.addAll(e.areas.map((a) => a.id));
      _requiresConfirmation = e.requiresConfirmation;
      if (e.eventAt != null) {
        _eventDate = DateTime(e.eventAt!.year, e.eventAt!.month, e.eventAt!.day);
        _eventTime = TimeOfDay(hour: e.eventAt!.hour, minute: e.eventAt!.minute);
      }
      if (_byAreas) _loadDepartments();
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _loadDepartments() async {
    if (_departments.isNotEmpty || _loadingDepts) return;
    setState(() => _loadingDepts = true);
    try {
      final depts = await TeamApi.listDepartments();
      if (mounted) setState(() => _departments = depts);
    } catch (_) {
      // sin red: se deja la lista vacía y el guardado avisará.
    } finally {
      if (mounted) setState(() => _loadingDepts = false);
    }
  }

  String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickEventDate() async {
    final now = DateTime.now();
    final picked = await pickWorkingDate(
      context,
      initialDate: _eventDate ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) setState(() => _eventDate = picked);
  }

  Future<void> _pickEventTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _eventTime ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null) setState(() => _eventTime = picked);
  }

  String? _validate() {
    if (_byAreas && _selectedAreas.isEmpty) {
      return 'Selecciona al menos un área para un anuncio por áreas.';
    }
    if (_eventDate != null && _eventTime == null) {
      return 'Indica también la hora de la reunión.';
    }
    if (_eventTime != null && _eventDate == null) {
      return 'Indica también la fecha de la reunión.';
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
      'body': _body.text.trim(),
      'scope': _byAreas ? 'areas' : 'general',
      if (_byAreas) 'areas': _selectedAreas.toList(),
      'requiresConfirmation': _requiresConfirmation,
      if (_requiresConfirmation && _eventDate != null && _eventTime != null)
        'eventAt': '${_ymd(_eventDate!)} ${_fmtTime(_eventTime!)}',
      if (_requiresConfirmation) 'locationLabel': _location.text.trim(),
    };

    try {
      if (widget.isEditing) {
        await InternalAnnouncementApi.update(widget.existing!.id, body);
      } else {
        await InternalAnnouncementApi.create(body);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on InternalAnnouncementException catch (e) {
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
        leading: const AppBackButton(),
        title: Text(widget.isEditing ? 'Editar anuncio' : 'Nuevo anuncio interno'),
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
              hintText: 'Título del anuncio',
              prefixIcon: const Icon(Icons.campaign_outlined),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Escribe un título.' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _body,
              hintText: 'Contenido del anuncio',
              maxLines: 5,
              prefixIcon: const Icon(Icons.notes_outlined),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Escribe el contenido.' : null,
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Se publica de inmediato: toda la audiencia lo recibe al guardar.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
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
                  onTap: () => setState(() => _byAreas = false),
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
                const Text(
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

            const SectionHeader(title: 'Confirmación de asistencia'),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Pedir confirmación de asistencia',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: const Text(
                      'Para reuniones: cada persona responde si asistirá o no. '
                      'Quien confirme "sí" recibe recordatorios hasta la reunión.',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                    value: _requiresConfirmation,
                    onChanged: (v) => setState(() => _requiresConfirmation = v),
                  ),
                  if (_requiresConfirmation) ...[
                    const Divider(
                        color: AppColors.surfaceBorder, height: AppSpacing.xl),
                    _PickerRow(
                      icon: Icons.calendar_today_outlined,
                      label: 'Fecha de la reunión',
                      value: _eventDate != null ? _ymd(_eventDate!) : 'Elegir',
                      onTap: _pickEventDate,
                    ),
                    _PickerRow(
                      icon: Icons.schedule,
                      label: 'Hora de la reunión',
                      value: _eventTime != null ? _fmtTime(_eventTime!) : 'Elegir',
                      onTap: _pickEventTime,
                    ),
                    const Padding(
                      padding: EdgeInsets.only(top: AppSpacing.xs),
                      child: Text(
                        'Sin fecha/hora el anuncio pide confirmación pero no manda recordatorios.',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppTextField(
                      controller: _location,
                      hintText: 'Lugar de la reunión (opcional)',
                      prefixIcon: const Icon(Icons.place_outlined),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: widget.isEditing ? 'Guardar cambios' : 'Publicar anuncio',
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
  final VoidCallback? onTap;

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
                style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                  color: AppColors.textPrimary, fontWeight: FontWeight.w600),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
