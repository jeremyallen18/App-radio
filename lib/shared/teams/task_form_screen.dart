import 'package:flutter/material.dart';

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/models/dept_task.dart';
import 'package:doliv_social/models/models.dart';
import 'package:doliv_social/services/team_service.dart';
import 'package:doliv_social/shared/teams/user_picker_sheet.dart';

/// Único formulario de creación/edición de tareas. Lo usan director y manager
/// para: crear tarea, crear subtarea (`parentId`) y editar (`existing`).
/// El empleado nunca lo abre (solo marca completadas desde el tablero).
class TaskFormScreen extends StatefulWidget {
  const TaskFormScreen({
    super.key,
    required this.departmentId,
    this.parentId,
    this.existing,
    this.members = const [],
  });

  final String departmentId;
  final String? parentId;
  final DeptTask? existing;

  /// Empleados del departamento, para el selector "Asignar a".
  final List<UserProfile> members;

  bool get isSubtask => parentId != null;
  bool get isEdit => existing != null;

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  UserProfile? _assignee;
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
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
      initialDate: _due ?? now,
      helpText: 'Fecha límite',
    );
    if (picked != null) setState(() => _due = picked);
  }

  Future<void> _pickRecurrenceUntil() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
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
      setState(() => _error = 'El título de la tarea es obligatorio.');
      return;
    }
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
          departmentId: widget.departmentId,
          parentId: widget.parentId,
          title: _title.text,
          description: _description.text,
          assignedTo: _assignee?.id,
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

  @override
  Widget build(BuildContext context) {
    final title = widget.isEdit
        ? 'Editar tarea'
        : (widget.isSubtask ? 'Nueva subtarea' : 'Nueva tarea');
    return AppScaffold(
      appBar: AppBar(leading: const AppBackButton(), title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl,
        ),
        children: [
          if (widget.isSubtask && !widget.isEdit)
            const Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.lg),
              child: Text(
                'Esta subtarea quedará dentro de la tarea principal seleccionada.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ),
          const Text('Título', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          const SizedBox(height: AppSpacing.sm),
          AppTextField(controller: _title, hintText: 'Ej. Cobertura de elecciones'),
          const SizedBox(height: AppSpacing.lg),
          const Text('Descripción (opcional)', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          const SizedBox(height: AppSpacing.sm),
          AppTextField(controller: _description, hintText: 'Detalles de la tarea', maxLines: 4),
          const SizedBox(height: AppSpacing.lg),
          _RowTile(
            icon: Icons.person_outline,
            label: 'Asignar a',
            value: _assignee?.name ?? 'Sin asignar',
            onTap: _pickAssignee,
            onClear: _assignee == null ? null : () => setState(() => _assignee = null),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 40, bottom: AppSpacing.sm),
            child: Text(
              _assignee == null
                  ? 'Sin responsable, solo un manager podrá marcarla como completada.'
                  : 'Solo ${_assignee!.name} podrá marcar esta tarea como completada.',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ),
          _RowTile(
            icon: Icons.event_outlined,
            label: 'Fecha límite',
            value: _due == null
                ? 'Sin fecha'
                : '${_due!.day.toString().padLeft(2, '0')}/${_due!.month.toString().padLeft(2, '0')}/${_due!.year}',
            onTap: _pickDue,
            onClear: _due == null ? null : () => setState(() => _due = null),
          ),
          const SizedBox(height: AppSpacing.sm),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _requiresEvidence,
            onChanged: (v) => setState(() => _requiresEvidence = v),
            title: const Text(
              'Pedir evidencia al completar',
              style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
            ),
            subtitle: const Text(
              'Habrá que adjuntar una foto o PDF para marcarla como completada.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ),
          if (_allowRecurrence) ...[
            const SizedBox(height: AppSpacing.md),
            const Text('Repetición', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<TaskRecurrence>(
              initialValue: _recurrence,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.repeat, color: AppColors.accent),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                for (final r in TaskRecurrence.values)
                  DropdownMenuItem(value: r, child: Text(r.label)),
              ],
              onChanged: (v) => setState(() {
                _recurrence = v ?? TaskRecurrence.none;
                if (_recurrence == TaskRecurrence.none) _recurrenceUntil = null;
              }),
            ),
            if (_recurrence != TaskRecurrence.none)
              _RowTile(
                icon: Icons.event_repeat_outlined,
                label: 'Repetir hasta',
                value: _recurrenceUntil == null
                    ? 'Sin límite'
                    : '${_recurrenceUntil!.day.toString().padLeft(2, '0')}/${_recurrenceUntil!.month.toString().padLeft(2, '0')}/${_recurrenceUntil!.year}',
                onTap: _pickRecurrenceUntil,
                onClear: _recurrenceUntil == null
                    ? null
                    : () => setState(() => _recurrenceUntil = null),
              ),
            if (_recurrence != TaskRecurrence.none)
              const Padding(
                padding: EdgeInsets.only(left: 40, top: 2),
                child: Text(
                  'Al cerrarse cada ocurrencia se crea la siguiente automáticamente.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ),
          ],
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
          ],
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: widget.isEdit ? 'GUARDAR CAMBIOS' : 'CREAR',
            loading: _saving,
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }
}

class _RowTile extends StatelessWidget {
  const _RowTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.onClear,
  });
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.accent),
      title: Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
      subtitle: Text(value, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
      trailing: onClear != null
          ? IconButton(onPressed: onClear, icon: const Icon(Icons.close, size: 18))
          : const Icon(Icons.chevron_right, color: AppColors.textMuted),
      onTap: onTap,
    );
  }
}
