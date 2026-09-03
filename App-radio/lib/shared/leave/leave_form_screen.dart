import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/models/leave_request.dart';
import 'package:doliv_social/services/leave_service.dart';
import 'package:doliv_social/shared/calendar/date_pickers.dart';

/// Formulario para solicitar un permiso (vacaciones / incapacidad / permiso).
/// La incapacidad EXIGE evidencia antes de poder enviar.
class LeaveFormScreen extends StatefulWidget {
  const LeaveFormScreen({super.key});

  @override
  State<LeaveFormScreen> createState() => _LeaveFormScreenState();
}

class _LeaveFormScreenState extends State<LeaveFormScreen> {
  LeaveType _type = LeaveType.vacaciones;
  DateTime? _start;
  DateTime? _end;
  final _reason = TextEditingController();
  File? _evidence;

  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  /// Vacaciones y permiso no pueden empezar en el pasado. La incapacidad sí
  /// (es retroactiva por naturaleza y la evidencia la respalda).
  bool get _allowsPast => _type == LeaveType.incapacidad;

  int get _businessDays {
    final s = _start, e = _end;
    if (s == null || e == null || e.isBefore(s)) return 0;
    var count = 0;
    for (var d = s; !d.isAfter(e); d = d.add(const Duration(days: 1))) {
      // Semana laboral lunes a sábado: solo el domingo no cuenta.
      if (d.weekday != DateTime.sunday) count++;
    }
    return count;
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final today = dateOnly(now);
    final DateTime first = _allowsPast ? DateTime(now.year - 1) : today;
    // Para vacaciones, el término no puede pasar de un mes desde el inicio.
    final DateTime last = (!isStart &&
            _type == LeaveType.vacaciones &&
            _start != null)
        ? oneCalendarMonthMaxEnd(_start!)
        : DateTime(now.year + 2);
    var initial = isStart ? (_start ?? now) : (_end ?? _start ?? now);
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;
    final picked = await pickWorkingDate(
      context,
      firstDate: first,
      lastDate: last,
      initialDate: initial,
      helpText: isStart ? 'Fecha de inicio' : 'Fecha de término',
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _start = picked;
        if (_end != null && _end!.isBefore(picked)) _end = picked;
        // Recorta un término que ahora quede fuera del mes permitido.
        if (_type == LeaveType.vacaciones && _end != null) {
          final max = oneCalendarMonthMaxEnd(picked);
          if (_end!.isAfter(max)) _end = max;
        }
      } else {
        _end = picked;
      }
    });
  }

  Future<void> _pickEvidence() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: AppColors.accent),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.accent),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final x = await ImagePicker().pickImage(source: source, imageQuality: 85, maxWidth: 2000);
    if (x == null || !mounted) return;
    setState(() => _evidence = File(x.path));
  }

  String? _validate() {
    if (_start == null) return 'Debes seleccionar una fecha de inicio.';
    if (_end == null) return 'Debes seleccionar una fecha de término.';
    if (_end!.isBefore(_start!)) {
      return 'La fecha de término no puede ser anterior a la fecha de inicio.';
    }
    if (_start!.weekday == DateTime.sunday || _end!.weekday == DateTime.sunday) {
      return 'El inicio y el término deben ser un día laboral (lunes a sábado).';
    }
    if (!_allowsPast && _start!.isBefore(dateOnly(DateTime.now()))) {
      return _type == LeaveType.vacaciones
          ? 'No puedes solicitar vacaciones para una fecha que ya pasó.'
          : 'No puedes solicitar un permiso para una fecha que ya pasó.';
    }
    if (_type == LeaveType.vacaciones &&
        _end!.isAfter(oneCalendarMonthMaxEnd(_start!))) {
      return 'Las vacaciones no pueden abarcar más de un mes.';
    }
    if (_type.requiresEvidence && _evidence == null) {
      return 'Debes adjuntar evidencia para solicitar una incapacidad.';
    }
    return null;
  }

  Future<void> _submit() async {
    final err = _validate();
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await LeaveApi.create(
        type: _type,
        start: _start!,
        end: _end!,
        reason: _reason.text,
        evidence: _evidence,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Solicitud enviada'),
          content: const Text(
            'Solicitud enviada correctamente.\n\nTu solicitud está pendiente de revisión.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } on LeaveException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final needsEvidence = _type.requiresEvidence;
    return AppScaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text(needsEvidence ? 'Solicitar incapacidad' : 'Solicitar permiso'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl,
        ),
        children: [
          const Text('Tipo de permiso',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<LeaveType>(
            initialValue: _type,
            items: [
              for (final t in LeaveType.values)
                DropdownMenuItem(
                  value: t,
                  child: Row(
                    children: [
                      Icon(t.icon, size: 16),
                      const SizedBox(width: AppSpacing.sm),
                      Text(t.label),
                    ],
                  ),
                ),
            ],
            onChanged: (v) => setState(() {
              _type = v ?? _type;
              final today = dateOnly(DateTime.now());
              // Al cambiar a un tipo que no admite pasado, descarta fechas ya
              // pasadas; y recorta el término si excede el mes de vacaciones.
              if (!_allowsPast) {
                if (_start != null && _start!.isBefore(today)) _start = null;
                if (_end != null && _end!.isBefore(today)) _end = null;
              }
              if (_type == LeaveType.vacaciones && _start != null && _end != null) {
                final max = oneCalendarMonthMaxEnd(_start!);
                if (_end!.isAfter(max)) _end = max;
              }
            }),
          ),
          const SizedBox(height: AppSpacing.lg),

          Row(
            children: [
              Expanded(child: _DateField(
                label: 'Fecha de inicio',
                value: _start,
                onTap: () => _pickDate(isStart: true),
              )),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: _DateField(
                label: 'Fecha de término',
                value: _end,
                onTap: () => _pickDate(isStart: false),
              )),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Días solicitados: ${_businessDays > 0 ? _businessDays : '—'}'
            '  (el director confirma el total al aprobar)',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: AppSpacing.lg),

          Text(
            needsEvidence ? 'Motivo' : 'Motivo (opcional)',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppTextField(
            controller: _reason,
            hintText: needsEvidence
                ? 'Describe el motivo de la incapacidad'
                : 'Escribe un motivo (opcional)',
            maxLines: 3,
          ),

          if (needsEvidence) ...[
            const SizedBox(height: AppSpacing.lg),
            const Text('Evidencia',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
            const SizedBox(height: AppSpacing.sm),
            _EvidencePicker(file: _evidence, onPick: _pickEvidence),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'La evidencia será revisada por el Director antes de aprobar la solicitud.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],

          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
          ],

          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: 'ENVIAR SOLICITUD',
            loading: _submitting,
            onPressed: _submitting ? null : _submit,
          ),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.label, required this.value, required this.onTap});
  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = value == null
        ? 'Seleccionar'
        : '${value!.day.toString().padLeft(2, '0')}/${value!.month.toString().padLeft(2, '0')}/${value!.year}';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.field),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.field),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
            const SizedBox(height: 2),
            Row(
              children: [
                const Icon(Icons.event, size: 15, color: AppColors.accent),
                const SizedBox(width: 6),
                Text(text, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EvidencePicker extends StatelessWidget {
  const _EvidencePicker({required this.file, required this.onPick});
  final File? file;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    if (file != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.card),
            child: Image.file(file!, height: 180, width: double.infinity, fit: BoxFit.cover),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton.icon(
            onPressed: onPick,
            icon: const Icon(Icons.refresh),
            label: const Text('Cambiar evidencia'),
          ),
        ],
      );
    }
    return OutlinedButton.icon(
      onPressed: onPick,
      icon: const Icon(Icons.photo_camera_outlined),
      label: const Text('AGREGAR EVIDENCIA'),
    );
  }
}
