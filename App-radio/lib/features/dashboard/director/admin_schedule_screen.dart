import 'package:flutter/material.dart';

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/models/attendance.dart';
import 'package:doliv_social/services/attendance_service.dart';

/// Administración de horarios de empleados. Solo el director puede crear o
/// modificar (`canEdit`); el manager los consulta. Cambiar un horario NO
/// altera la asistencia ya registrada (el backend congela el horario por día).
class AdminScheduleScreen extends StatefulWidget {
  const AdminScheduleScreen({super.key});

  @override
  State<AdminScheduleScreen> createState() => _AdminScheduleScreenState();
}

class _AdminScheduleScreenState extends State<AdminScheduleScreen> {
  List<EmployeeScheduleRow> _rows = const [];
  bool _canEdit = false;
  bool _loading = true;
  String? _error;

  /// Modo de selección múltiple para asignar el mismo horario a varios.
  bool _selectMode = false;
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _toggleSelectMode() {
    setState(() {
      _selectMode = !_selectMode;
      _selected.clear();
    });
  }

  void _toggleOne(String id) {
    setState(() {
      if (!_selected.remove(id)) _selected.add(id);
    });
  }

  void _selectAllOrNone() {
    setState(() {
      if (_selected.length == _rows.length) {
        _selected.clear();
      } else {
        _selected
          ..clear()
          ..addAll(_rows.map((r) => r.employeeId));
      }
    });
  }

  Future<void> _assignToSelected() async {
    if (_selected.isEmpty) return;
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (_) => _ScheduleEditor(bulkIds: _selected.toList()),
    );
    if (result == true && mounted) {
      _toggleSelectMode();
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await AttendanceApi.adminSchedules();
      if (!mounted) return;
      setState(() {
        _rows = result.rows;
        _canEdit = result.canEdit;
        _loading = false;
      });
    } on AttendanceException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _edit(EmployeeScheduleRow row) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (_) => _ScheduleEditor(row: row),
    );
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        leading: _selectMode
            ? IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Salir de selección',
                onPressed: _toggleSelectMode,
              )
            : const BackButton(),
        title: Text(_selectMode
            ? '${_selected.length} seleccionados'
            : 'Horarios de empleados'),
        actions: [
          if (_canEdit && _rows.isNotEmpty && !_selectMode)
            IconButton(
              icon: const Icon(Icons.checklist_rtl),
              tooltip: 'Asignar a varios',
              onPressed: _toggleSelectMode,
            ),
          if (_selectMode)
            TextButton(
              onPressed: _selectAllOrNone,
              child: Text(
                _selected.length == _rows.length ? 'Ninguno' : 'Todos',
                style: const TextStyle(color: AppColors.accentStrong),
              ),
            ),
        ],
      ),
      body: Builder(
        builder: (context) {
          if (_loading) return const LoadingState();
          if (_error != null) {
            return ErrorState(message: _error!, onRetry: _load);
          }
          if (_rows.isEmpty) {
            return const EmptyState(
              icon: Icons.schedule,
              title: 'No hay empleados para mostrar',
            );
          }
          return RefreshIndicator(
            color: AppColors.accent,
            onRefresh: _load,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.xxl,
              ),
              itemCount: _rows.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (_, i) {
                if (i == 0) {
                  return Text(
                    !_canEdit
                        ? 'Solo el director puede modificar los horarios.'
                        : _selectMode
                            ? 'Elige a los empleados y asigna el mismo horario a todos.'
                            : 'Toca un empleado para editar su horario, o usa la lista para asignar a varios.',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                  );
                }
                final row = _rows[i - 1];
                return AppFadeIn.staggered(
                  index: i - 1,
                  child: _ScheduleRowCard(
                    row: row,
                    selectMode: _selectMode,
                    selected: _selected.contains(row.employeeId),
                    onTap: !_canEdit
                        ? null
                        : _selectMode
                            ? () => _toggleOne(row.employeeId)
                            : () => _edit(row),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: (_selectMode && _selected.isNotEmpty)
          ? FloatingActionButton.extended(
              onPressed: _assignToSelected,
              icon: const Icon(Icons.schedule),
              label: Text('Asignar horario (${_selected.length})'),
            )
          : null,
    );
  }
}

class _ScheduleRowCard extends StatelessWidget {
  const _ScheduleRowCard({
    required this.row,
    this.onTap,
    this.selectMode = false,
    this.selected = false,
  });
  final EmployeeScheduleRow row;
  final VoidCallback? onTap;
  final bool selectMode;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final s = row.schedule;
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          if (selectMode) ...[
            Icon(
              selected ? Icons.check_box : Icons.check_box_outline_blank,
              color: selected ? AppColors.accent : AppColors.textMuted,
            ),
            const SizedBox(width: AppSpacing.md),
          ],
          IdentityAvatar(id: row.name),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 6),
                if (s == null)
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: AppBadge(
                      label: 'Sin horario asignado',
                      variant: AppBadgeVariant.warning,
                    ),
                  )
                else
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      _MetaChip(icon: Icons.login, label: s.entryTime),
                      _MetaChip(icon: Icons.logout, label: s.exitTime),
                      _MetaChip(icon: Icons.restaurant_outlined, label: s.mealTime),
                      _MetaChip(
                        icon: Icons.timer_outlined,
                        label: '${s.mealMaxMinutes} min',
                      ),
                    ],
                  ),
              ],
            ),
          ),
          if (onTap != null && !selectMode)
            const Icon(Icons.edit_outlined, color: AppColors.accent, size: 18),
        ],
      ),
    );
  }
}

/// Chip compacto de solo lectura para un dato del horario (hora o límite).
class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.bgBase,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.textMuted),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Hoja de edición de horario. Con [row] edita a una persona; con [bulkIds]
/// asigna el MISMO horario a todos esos ids en una operación.
class _ScheduleEditor extends StatefulWidget {
  const _ScheduleEditor({this.row, this.bulkIds})
      : assert(row != null || bulkIds != null);
  final EmployeeScheduleRow? row;
  final List<String>? bulkIds;

  @override
  State<_ScheduleEditor> createState() => _ScheduleEditorState();
}

class _ScheduleEditorState extends State<_ScheduleEditor> {
  late String _entry;
  late String _exit;
  late String _meal;
  late TextEditingController _limit;
  bool _saving = false;
  String? _error;

  bool get _isBulk => widget.bulkIds != null;

  @override
  void initState() {
    super.initState();
    final s = widget.row?.schedule;
    _entry = s?.entryTime ?? '09:00';
    _exit = s?.exitTime ?? '17:00';
    _meal = s?.mealTime ?? '14:00';
    _limit = TextEditingController(text: (s?.mealMaxMinutes ?? 60).toString());
  }

  @override
  void dispose() {
    _limit.dispose();
    super.dispose();
  }

  Future<void> _pickTime(String current, ValueChanged<String> onPicked) async {
    final parts = current.split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(parts.first) ?? 9,
        minute: int.tryParse(parts.last) ?? 0,
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;
    onPicked('${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}');
  }

  Future<void> _save() async {
    final limit = int.tryParse(_limit.text.trim());
    if (limit == null || limit < 1 || limit > 240) {
      setState(() => _error = 'El límite de comida debe estar entre 1 y 240 minutos.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      String message = 'Horario guardado correctamente';
      if (_isBulk) {
        final r = await AttendanceApi.bulkSaveSchedule(
          employeeIds: widget.bulkIds!,
          entryTime: _entry,
          exitTime: _exit,
          mealTime: _meal,
          mealMaxMinutes: limit,
        );
        message = r.message;
      } else {
        await AttendanceApi.saveSchedule(
          widget.row!.employeeId,
          entryTime: _entry,
          exitTime: _exit,
          mealTime: _meal,
          mealMaxMinutes: limit,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } on AttendanceException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isBulk
                ? 'Asignar horario a ${widget.bulkIds!.length} empleados'
                : 'Horario de ${widget.row!.name}',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _timeTile('Horario de entrada', _entry, (v) => setState(() => _entry = v)),
          _timeTile('Horario de salida', _exit, (v) => setState(() => _exit = v)),
          _timeTile('Hora de comida', _meal, (v) => setState(() => _meal = v)),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _limit,
            hintText: 'Límite de comida (minutos)',
            textInputType: TextInputType.number,
            prefixIcon: const Icon(Icons.timer_outlined),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
          ],
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'GUARDAR CAMBIOS',
            loading: _saving,
            onPressed: _saving ? null : _save,
          ),
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: TextButton(
              onPressed: _saving ? null : () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeTile(String label, String value, ValueChanged<String> onPicked) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
      trailing: OutlinedButton.icon(
        onPressed: () => _pickTime(value, onPicked),
        icon: const Icon(Icons.schedule, size: 16),
        label: Text(value),
      ),
    );
  }
}
