import 'package:flutter/material.dart';

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/shared/calendar/date_pickers.dart';

/// Hoja inferior de aprobación: deja al director autorizar un periodo distinto
/// al solicitado. Devuelve el rango elegido, o `null` si cancela.
Future<DateTimeRange?> showLeaveApprovalSheet(
  BuildContext context, {
  required DateTime initialStart,
  required DateTime initialEnd,
}) {
  return showModalBottomSheet<DateTimeRange>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    builder: (sheetContext) => _LeaveApprovalSheet(
      initialStart: initialStart,
      initialEnd: initialEnd,
    ),
  );
}

/// Hoja inferior con un único campo de texto para el motivo (rechazo o
/// revocación). Devuelve el texto sin espacios sobrantes, o `null` si se cancela
/// o se deja vacío.
Future<String?> showLeaveReasonSheet(
  BuildContext context, {
  required String title,
  required String hint,
  required String confirmLabel,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    builder: (sheetContext) => _LeaveReasonSheet(
      title: title,
      hint: hint,
      confirmLabel: confirmLabel,
    ),
  );
}

class _LeaveApprovalSheet extends StatefulWidget {
  const _LeaveApprovalSheet({required this.initialStart, required this.initialEnd});
  final DateTime initialStart;
  final DateTime initialEnd;

  @override
  State<_LeaveApprovalSheet> createState() => _LeaveApprovalSheetState();
}

class _LeaveApprovalSheetState extends State<_LeaveApprovalSheet> {
  late DateTime _start = widget.initialStart;
  late DateTime _end = widget.initialEnd;

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
          const Text('Fechas autorizadas',
              style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 17)),
          const SizedBox(height: 4),
          const Text(
            'Puedes autorizar un periodo distinto al solicitado.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: AppSpacing.lg),
          _SheetDateRow(
            label: 'Inicio',
            value: _start,
            onPick: () async {
              final p = await pickWorkingDate(
                context,
                firstDate: DateTime(_start.year - 1),
                lastDate: DateTime(_start.year + 2),
                initialDate: _start,
              );
              if (p != null) {
                setState(() {
                  _start = p;
                  if (_end.isBefore(p)) _end = p;
                });
              }
            },
          ),
          _SheetDateRow(
            label: 'Término',
            value: _end,
            onPick: () async {
              final p = await pickWorkingDate(
                context,
                firstDate: DateTime(_start.year - 1),
                lastDate: DateTime(_start.year + 2),
                initialDate: _end,
              );
              if (p != null) {
                setState(() => _end = p);
              }
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'APROBAR',
            onPressed: () => Navigator.pop(
              context,
              DateTimeRange(start: _start, end: _end),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaveReasonSheet extends StatefulWidget {
  const _LeaveReasonSheet({
    required this.title,
    required this.hint,
    required this.confirmLabel,
  });
  final String title;
  final String hint;
  final String confirmLabel;

  @override
  State<_LeaveReasonSheet> createState() => _LeaveReasonSheetState();
}

class _LeaveReasonSheetState extends State<_LeaveReasonSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
          Text(widget.title,
              style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 17)),
          const SizedBox(height: AppSpacing.md),
          AppTextField(controller: _controller, hintText: widget.hint, maxLines: 3),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: widget.confirmLabel,
            onPressed: () {
              final text = _controller.text.trim();
              if (text.isEmpty) return;
              Navigator.pop(context, text);
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetDateRow extends StatelessWidget {
  const _SheetDateRow({required this.label, required this.value, required this.onPick});
  final String label;
  final DateTime value;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
      trailing: OutlinedButton.icon(
        onPressed: onPick,
        icon: const Icon(Icons.event, size: 16),
        label: Text(
          '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}',
        ),
      ),
    );
  }
}
