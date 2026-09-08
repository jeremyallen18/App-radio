import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/models/leave_request.dart';
import 'package:doliv_social/services/leave_service.dart';
import 'package:doliv_social/shared/calendar/date_pickers.dart';

/// Formulario para solicitar un permiso o una incapacidad. Las vacaciones ya
/// no se solicitan desde aquí. La incapacidad EXIGE evidencia antes de enviar.
class LeaveFormScreen extends StatefulWidget {
  const LeaveFormScreen({super.key});

  @override
  State<LeaveFormScreen> createState() => _LeaveFormScreenState();
}

class _LeaveFormScreenState extends State<LeaveFormScreen> {
  /// Tipos que el trabajador puede solicitar (vacaciones excluida).
  static const List<LeaveType> _selectableTypes = [
    LeaveType.permiso,
    LeaveType.incapacidad,
  ];

  LeaveType _type = LeaveType.permiso;
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

  DateTime get _today => dateOnly(DateTime.now());

  /// Fecha de INICIO más antigua permitida:
  ///  - incapacidad: hasta 3 días hacia atrás (la evidencia médica lo respalda).
  ///  - vacaciones / permiso: nunca en el pasado.
  DateTime get _minStart => _type == LeaveType.incapacidad
      ? _today.subtract(const Duration(days: 3))
      : _today;

  /// Fecha de TÉRMINO más lejana permitida, independiente del inicio elegido:
  ///  - permiso: un mes de calendario desde HOY (todo el permiso entra ahí).
  ///  - incapacidad: un año desde hoy.
  ///  - vacaciones: dos años (el tope real —un mes desde el inicio— se aplica
  ///    aparte en cuanto hay fecha de inicio).
  DateTime get _maxEnd => switch (_type) {
        LeaveType.permiso => oneCalendarMonthMaxEnd(_today),
        LeaveType.incapacidad =>
          DateTime(_today.year + 1, _today.month, _today.day),
        LeaveType.vacaciones => DateTime(_today.year + 2),
      };

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
    final DateTime first = _minStart;
    // Para vacaciones el término no puede pasar de un mes desde el inicio ya
    // elegido; el resto de tipos usan la ventana fija del tipo.
    final DateTime last = (!isStart &&
            _type == LeaveType.vacaciones &&
            _start != null)
        ? oneCalendarMonthMaxEnd(_start!)
        : _maxEnd;
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
    // Ventana de fechas por tipo (debe coincidir con leave_requests.php):
    //  vacaciones : inicio ≥ hoy, término ≤ un mes de calendario desde el inicio.
    //  permiso    : inicio ≥ hoy, término ≤ un mes de calendario desde HOY.
    //  incapacidad: inicio ≥ hoy − 3 días, término ≤ un año desde hoy.
    final today = _today;
    switch (_type) {
      case LeaveType.vacaciones:
        if (_start!.isBefore(today)) {
          return 'No puedes solicitar vacaciones para una fecha que ya pasó.';
        }
        if (_end!.isAfter(oneCalendarMonthMaxEnd(_start!))) {
          return 'Las vacaciones no pueden abarcar más de un mes.';
        }
      case LeaveType.permiso:
        if (_start!.isBefore(today)) {
          return 'No puedes solicitar un permiso para una fecha que ya pasó.';
        }
        if (_end!.isAfter(oneCalendarMonthMaxEnd(today))) {
          return 'Un permiso solo puede solicitarse hasta un mes a partir de hoy.';
        }
      case LeaveType.incapacidad:
        if (_start!.isBefore(today.subtract(const Duration(days: 3)))) {
          return 'La incapacidad puede iniciar como máximo 3 días antes de hoy.';
        }
        if (_end!.isAfter(DateTime(today.year + 1, today.month, today.day))) {
          return 'Una incapacidad no puede extenderse más de un año a partir de hoy.';
        }
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
        leading: const BackButton(),
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
              for (final t in _selectableTypes)
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
              // Al cambiar de tipo, descarta las fechas que queden fuera de la
              // ventana permitida del nuevo tipo y recorta el término si excede
              // el mes de vacaciones.
              bool inWindow(DateTime d) =>
                  !d.isBefore(_minStart) && !d.isAfter(_maxEnd);
              if (_start != null && !inWindow(_start!)) _start = null;
              if (_end != null && !inWindow(_end!)) _end = null;
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
