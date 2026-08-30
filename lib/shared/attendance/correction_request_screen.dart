import 'package:flutter/material.dart';

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/models/attendance.dart';
import 'package:doliv_social/services/attendance_service.dart';

/// Pantalla del empleado para pedir una corrección de asistencia ("olvidé
/// marcar salida el 25", "entré a las 9:05 pero quedó 9:40"). El manager de
/// su departamento la aprueba o la rechaza.
class CorrectionRequestScreen extends StatefulWidget {
  const CorrectionRequestScreen({super.key, this.initialDate});

  /// Día que venía seleccionado en el historial, si lo hubo.
  final DateTime? initialDate;

  @override
  State<CorrectionRequestScreen> createState() => _CorrectionRequestScreenState();
}

class _CorrectionRequestScreenState extends State<CorrectionRequestScreen> {
  final _reason = TextEditingController();
  DateTime _date = DateTime.now();
  CorrectionKind _kind = CorrectionKind.salida;
  TimeOfDay _time = const TimeOfDay(hour: 18, minute: 0);

  List<AttendanceCorrection> _mine = const [];
  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialDate != null) _date = widget.initialDate!;
    _load();
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final mine = await AttendanceApi.myCorrections();
      if (!mounted) return;
      setState(() {
        _mine = mine;
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

  String get _timeText =>
      '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}';

  String get _dateText =>
      '${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}/${_date.year}';

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
      initialDate: _date.isAfter(now) ? now : _date,
      helpText: 'Día del fichaje',
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _submit() async {
    if (_reason.text.trim().isEmpty) {
      setState(() => _error = 'Explica brevemente qué pasó.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await AttendanceApi.createCorrection(
        workDate: _date,
        kind: _kind,
        requestedTime: _timeText,
        reason: _reason.text,
      );
      if (!mounted) return;
      _reason.clear();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Solicitud enviada.')));
      setState(() => _sending = false);
      _load();
    } on AttendanceException catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
          leading: const AppBackButton(), title: const Text('Solicitar corrección')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
        children: [
          const Text(
            'Pide corregir un fichaje que olvidaste o que quedó con la hora '
            'equivocada. Tu manager lo revisa antes de aplicarse.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: AppSpacing.lg),
          _row(Icons.event_outlined, 'Día', _dateText, _pickDate),
          const SizedBox(height: AppSpacing.md),
          const Text('Fichaje', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<CorrectionKind>(
            initialValue: _kind,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.punch_clock_outlined, color: AppColors.accent),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              for (final k in CorrectionKind.values)
                DropdownMenuItem(value: k, child: Text(k.label)),
            ],
            onChanged: (v) => setState(() => _kind = v ?? _kind),
          ),
          const SizedBox(height: AppSpacing.md),
          _row(Icons.schedule, 'Hora correcta', _timeText, _pickTime),
          const SizedBox(height: AppSpacing.md),
          const Text('Motivo', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          const SizedBox(height: AppSpacing.sm),
          AppTextField(
              controller: _reason,
              hintText: 'Ej. Salí a las 18:00 pero se me olvidó marcar.',
              maxLines: 3),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
          ],
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'ENVIAR SOLICITUD',
            loading: _sending,
            onPressed: _sending ? null : _submit,
          ),
          const SizedBox(height: AppSpacing.xl),
          const SectionHeader(title: 'Mis solicitudes'),
          const SizedBox(height: AppSpacing.sm),
          if (_loading)
            const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: LoadingState())
          else if (_mine.isEmpty)
            const Text('Todavía no has pedido correcciones.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13))
          else
            for (final c in _mine) ...[
              _MyCorrectionTile(correction: c),
              const SizedBox(height: AppSpacing.sm),
            ],
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String value, VoidCallback onTap) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.accent),
      title: Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
      subtitle: Text(value,
          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
      onTap: onTap,
    );
  }
}

class _MyCorrectionTile extends StatelessWidget {
  const _MyCorrectionTile({required this.correction});
  final AttendanceCorrection correction;

  @override
  Widget build(BuildContext context) {
    final c = correction;
    final color = switch (c.status) {
      CorrectionStatus.pendiente => AppColors.warning,
      CorrectionStatus.aprobado => AppColors.success,
      CorrectionStatus.rechazado => AppColors.error,
    };
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('${c.kindLabel} · ${c.workDateLabel} · ${c.requestedTime}',
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(c.status.label,
                    style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(c.reason, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          if ((c.reviewNote ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Nota del manager: ${c.reviewNote}',
                style: TextStyle(color: color, fontSize: 12)),
          ],
        ],
      ),
    );
  }
}
