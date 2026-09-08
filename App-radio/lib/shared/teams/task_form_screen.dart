import 'package:flutter/material.dart';

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/models/dept_task.dart';
import 'package:doliv_social/models/models.dart';
import 'package:doliv_social/services/team_service.dart';
import 'package:doliv_social/shared/teams/user_picker_sheet.dart';
import 'package:doliv_social/shared/calendar/date_pickers.dart';

/// Único formulario de creación/edición de tareas. Lo usan director y manager
/// para: crear tarea, crear subtarea (`parentId`) y editar (`existing`).
/// El empleado nunca lo abre (solo marca completadas desde el tablero).
///
/// Tres paneles: *Qué* (título y descripción), *Quién y cuándo* (responsable
/// y fecha límite con atajos) y *Opciones* (evidencia, repetición). El botón
/// de guardar va fijo abajo.
class TaskFormScreen extends StatefulWidget {
  const TaskFormScreen({
    super.key,
    this.departmentId,
    this.parentId,
    this.existing,
    this.members = const [],
    this.asDirector = false,
    this.departments = const [],
  });

  /// Departamento de la tarea. Puede venir vacío solo cuando el director
  /// abre el formulario desde su lista de departamentos: entonces lo elige
  /// aquí.
  final String? departmentId;
  final String? parentId;
  final DeptTask? existing;

  /// Gente del departamento, para el selector "Responsable" (manager).
  final List<UserProfile> members;

  /// Director creando una tarea principal: elige DEPARTAMENTO, no persona.
  /// El backend se la asigna al manager de esa área, que la desglosa.
  final bool asDirector;

  /// Departamentos a elegir (solo en modo director).
  final List<DepartmentInfo> departments;

  bool get isSubtask => parentId != null;
  bool get isEdit => existing != null;

  /// El director elige departamento en tareas principales; en subtareas
  /// (desglosando una tarea de un manager) actúa como manager.
  bool get picksDepartment => asDirector && !isSubtask;

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  UserProfile? _assignee;
  String? _departmentId;
  DateTime? _due;
  bool _requiresEvidence = false;
  TaskRecurrence _recurrence = TaskRecurrence.none;
  DateTime? _recurrenceUntil;
  bool _saving = false;
  String? _error;

  /// La recurrencia solo aplica a tareas de nivel superior.
  bool get _allowRecurrence => !widget.isSubtask;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _departmentId = e?.departmentId ?? widget.departmentId;
    _title = TextEditingController(text: e?.title ?? '');
    _description = TextEditingController(text: e?.description ?? '');
    _due = e?.dueDate;
    _requiresEvidence = e?.requiresEvidence ?? false;
    _recurrence = e?.recurrence ?? TaskRecurrence.none;
    _recurrenceUntil = e?.recurrenceUntil;

    // Conserva el asignado actual aunque ya no esté en la lista de miembros
    // (p. ej. si fue removido del departamento): así al editar no se pierde
    // silenciosamente.
    final ref = e?.assignedTo;
    if (ref != null) {
      _assignee = widget.members.cast<UserProfile?>().firstWhere(
            (m) => m?.id == ref.id,
            orElse: () => UserProfile(
              id: ref.id,
              name: ref.name,
              email: ref.email,
              role: appRoleFromString(ref.role),
            ),
          );
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickAssignee() async {
    if (widget.members.isEmpty) {
      _snack('Este equipo aún no tiene empleados que asignar.');
      return;
    }
    final u = await pickPerson(context, title: 'Asignar a', people: widget.members);
    if (u != null) setState(() => _assignee = u);
  }

  Future<void> _pickDue() async {
    final now = DateTime.now();
    final picked = await pickWorkingDate(
      context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
      initialDate: _due ?? now,
      helpText: 'Fecha límite',
    );
    if (picked != null) setState(() => _due = picked);
  }

  Future<void> _pickRecurrenceUntil() async {
    final now = DateTime.now();
    final picked = await pickWorkingDate(
      context,
      firstDate: now,
      lastDate: DateTime(now.year + 3),
      initialDate: _recurrenceUntil ?? now,
      helpText: 'Repetir hasta',
    );
    if (picked != null) setState(() => _recurrenceUntil = picked);
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Ponle un título a la tarea.');
      return;
    }
    if (_departmentId == null || _departmentId!.isEmpty) {
      setState(() => _error = 'Elige el departamento que hará la tarea.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final recurrence = _allowRecurrence ? _recurrence : TaskRecurrence.none;
      if (widget.isEdit) {
        await DeptTaskApi.update(
          widget.existing!.id,
          title: _title.text,
          description: _description.text,
          assignedTo: _assignee?.id,
          clearAssignee: _assignee == null,
          dueDate: _due,
          clearDueDate: _due == null,
          requiresEvidence: _requiresEvidence,
          recurrence: recurrence,
          recurrenceUntil: _recurrenceUntil,
        );
      } else {
        await DeptTaskApi.create(
          departmentId: _departmentId,
          parentId: widget.parentId,
          title: _title.text,
          description: _description.text,
          // En modo director el backend asigna al manager del departamento.
          assignedTo: widget.picksDepartment ? null : _assignee?.id,
          dueDate: _due,
          requiresEvidence: _requiresEvidence,
          recurrence: recurrence,
          recurrenceUntil: _recurrenceUntil,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on TeamException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.message;
      });
    }
  }

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  static bool _sameDay(DateTime? a, DateTime b) =>
      a != null && a.year == b.year && a.month == b.month && a.day == b.day;

  static String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final title = widget.isEdit
        ? 'Editar tarea'
        : (widget.isSubtask ? 'Nueva subtarea' : 'Nueva tarea');
    final today = _today();
    final tomorrow = today.add(const Duration(days: 1));

    return AppScaffold(
      appBar: AppBar(automaticallyImplyLeading: false, title: Text(title)),
      padding: EdgeInsets.zero,
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
              ),
            AppButton(
              label: widget.isEdit ? 'Guardar cambios' : (widget.isSubtask ? 'Crear subtarea' : 'Crear tarea'),
              loading: _saving,
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xl),
        children: [
          if (widget.isSubtask && !widget.isEdit)
            const Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.md),
              child: Row(
                children: [
                  Icon(Icons.subdirectory_arrow_right_rounded, size: 16, color: AppColors.textMuted),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Quedará dentro de la tarea principal seleccionada.',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          _Panel(
            title: 'Qué',
            children: [
              _Label('Título'),
              AppTextField(controller: _title, hintText: 'Ej. Cobertura de elecciones'),
              const SizedBox(height: AppSpacing.md),
              _Label('Descripción', hint: 'opcional'),
              AppTextField(controller: _description, hintText: 'Qué hay que hacer y qué entregar', maxLines: 4),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _Panel(
            title: 'Quién y cuándo',
            children: [
              if (widget.picksDepartment) ...[
                _Label('Departamento'),
                _DepartmentPicker(
                  departments: widget.departments,
                  selectedId: _departmentId,
                  locked: widget.isEdit,
                  onSelect: (id) => setState(() => _departmentId = id),
                ),
              ] else ...[
                _Label('Responsable'),
                _AssigneeTile(
                  assignee: _assignee,
                  onTap: _pickAssignee,
                  onClear: _assignee == null ? null : () => setState(() => _assignee = null),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 4),
                  child: Text(
                    _assignee == null
                        ? 'Sin responsable, solo un manager podrá marcarla como completada.'
                        : 'Solo ${_assignee!.name} podrá marcarla como completada.',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              _Label('Fecha límite'),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  AppFilterChip(label: 'Sin fecha', selected: _due == null, onTap: () => setState(() => _due = null)),
                  AppFilterChip(label: 'Hoy', selected: _sameDay(_due, today), onTap: () => setState(() => _due = today)),
                  AppFilterChip(label: 'Mañana', selected: _sameDay(_due, tomorrow), onTap: () => setState(() => _due = tomorrow)),
                  AppFilterChip(
                    label: _due != null && !_sameDay(_due, today) && !_sameDay(_due, tomorrow)
                        ? _fmt(_due!)
                        : 'Elegir…',
                    selected: _due != null && !_sameDay(_due, today) && !_sameDay(_due, tomorrow),
                    onTap: _pickDue,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _Panel(
            title: 'Opciones',
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _requiresEvidence,
                onChanged: (v) => setState(() => _requiresEvidence = v),
                secondary: const Icon(Icons.photo_camera_outlined, color: AppColors.accent),
                title: const Text(
                  'Pedir evidencia al completar',
                  style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: const Text(
                  'Habrá que adjuntar una foto para marcarla como completada.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ),
              if (_allowRecurrence) ...[
                const SizedBox(height: AppSpacing.sm),
                _Label('Repetición'),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final r in TaskRecurrence.values)
                      AppFilterChip(
                        label: r.label,
                        selected: _recurrence == r,
                        onTap: () => setState(() {
                          _recurrence = r;
                          if (r == TaskRecurrence.none) _recurrenceUntil = null;
                        }),
                      ),
                  ],
                ),
                if (_recurrence != TaskRecurrence.none) ...[
                  const SizedBox(height: AppSpacing.md),
                  _Label('Repetir hasta'),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      AppFilterChip(
                        label: 'Sin límite',
                        selected: _recurrenceUntil == null,
                        onTap: () => setState(() => _recurrenceUntil = null),
                      ),
                      AppFilterChip(
                        label: _recurrenceUntil == null ? 'Elegir…' : _fmt(_recurrenceUntil!),
                        selected: _recurrenceUntil != null,
                        onTap: _pickRecurrenceUntil,
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 6, left: 4),
                    child: Text(
                      'Al cerrarse cada ocurrencia se crea la siguiente automáticamente.',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title.toUpperCase(),
              style: const TextStyle(
                color: AppColors.accentStrong,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text, {this.hint});
  final String text;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.sm),
      child: Row(
        children: [
          Text(text, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
          if (hint != null) ...[
            const SizedBox(width: 6),
            Text(hint!, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ],
        ],
      ),
    );
  }
}

/// Chips de departamento (modo director) + nota de a quién le llegará.
class _DepartmentPicker extends StatelessWidget {
  const _DepartmentPicker({
    required this.departments,
    required this.selectedId,
    required this.locked,
    required this.onSelect,
  });

  final List<DepartmentInfo> departments;
  final String? selectedId;

  /// Al editar no se cambia de departamento (la tarea ya está en su tablero).
  final bool locked;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final selected = departments.cast<DepartmentInfo?>().firstWhere(
          (d) => d?.id == selectedId,
          orElse: () => null,
        );
    final String note;
    if (selected == null) {
      note = departments.isEmpty
          ? 'Todavía no hay departamentos. Créalos desde "Equipos y departamentos".'
          : 'La tarea le llegará al manager del departamento, que la repartirá con su equipo.';
    } else if ((selected.managerEmail ?? '').isEmpty) {
      note = '${selected.name} aún no tiene manager: asigna uno antes de crear la tarea.';
    } else {
      note = 'Le llegará a ${selected.managerEmail} (manager de ${selected.name}) para que la reparta con su equipo.';
    }
    final noteColor = selected != null && (selected.managerEmail ?? '').isEmpty
        ? AppColors.warning
        : AppColors.textMuted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (locked)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Row(
              children: [
                const Icon(Icons.groups_2_outlined, size: 16, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Text(
                  selected?.name ?? 'Departamento',
                  style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          )
        else
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final d in departments)
                AppFilterChip(
                  label: d.name,
                  selected: d.id == selectedId,
                  onTap: () => onSelect(d.id),
                ),
            ],
          ),
        Padding(
          padding: const EdgeInsets.only(top: 6, left: 4),
          child: Text(note, style: TextStyle(color: noteColor, fontSize: 11)),
        ),
      ],
    );
  }
}

class _AssigneeTile extends StatelessWidget {
  const _AssigneeTile({required this.assignee, required this.onTap, this.onClear});
  final UserProfile? assignee;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final a = assignee;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.field),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.field),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.field),
            border: Border.all(color: a == null ? AppColors.surfaceBorder : AppColors.accent.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              if (a == null)
                const CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.surfaceBorder,
                  child: Icon(Icons.person_add_alt_1_outlined, size: 16, color: AppColors.textMuted),
                )
              else
                IdentityAvatar(id: a.email, label: a.name, radius: 16, photoUrl: a.photoUrl),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  a?.name ?? 'Elegir a alguien del equipo',
                  style: TextStyle(
                    color: a == null ? AppColors.textMuted : AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (onClear != null)
                IconButton(
                  onPressed: onClear,
                  tooltip: 'Quitar responsable',
                  icon: const Icon(Icons.close_rounded, size: 18),
                  visualDensity: VisualDensity.compact,
                )
              else
                const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
