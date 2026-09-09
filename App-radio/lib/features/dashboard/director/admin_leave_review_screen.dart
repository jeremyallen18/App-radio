import 'package:flutter/material.dart';

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/models/leave_request.dart';
import 'package:doliv_social/services/leave_service.dart';
import 'package:doliv_social/features/dashboard/director/leave_review_sheets.dart';
import 'package:doliv_social/shared/widgets/evidence_viewer.dart';

/// Revisión de una solicitud por el director: ver toda la información y la
/// evidencia, aprobar (pudiendo cambiar el rango de fechas), rechazar (motivo
/// obligatorio) o revocar un permiso ya aprobado (motivo obligatorio).
class AdminLeaveReviewScreen extends StatefulWidget {
  const AdminLeaveReviewScreen({super.key, required this.requestId});
  final String requestId;

  @override
  State<AdminLeaveReviewScreen> createState() => _AdminLeaveReviewScreenState();
}

class _AdminLeaveReviewScreenState extends State<AdminLeaveReviewScreen> {
  LeaveRequest? _req;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await LeaveApi.adminGet(widget.requestId);
      if (!mounted) return;
      setState(() {
        _req = r;
        _loading = false;
      });
    } on LeaveException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _approve() async {
    final r = _req!;
    final start = r.requestedStart ?? DateTime.now();
    final end = r.requestedEnd ?? start;

    final range = await showLeaveApprovalSheet(
      context,
      initialStart: start,
      initialEnd: end,
    );
    if (range == null) return;

    setState(() => _busy = true);
    try {
      final updated = await LeaveApi.approve(widget.requestId,
          approvedStart: range.start, approvedEnd: range.end);
      if (!mounted) return;
      setState(() {
        _req = updated;
        _busy = false;
      });
      _snack('Solicitud aprobada.');
    } on LeaveException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack(e.message);
    }
  }

  Future<void> _reasonAction({
    required String title,
    required String hint,
    required String confirmLabel,
    required Future<LeaveRequest> Function(String reason) run,
    required String okMessage,
  }) async {
    final reason = await showLeaveReasonSheet(
      context,
      title: title,
      hint: hint,
      confirmLabel: confirmLabel,
    );
    if (reason == null || reason.isEmpty) return;

    setState(() => _busy = true);
    try {
      final updated = await run(reason);
      if (!mounted) return;
      setState(() {
        _req = updated;
        _busy = false;
      });
      _snack(okMessage);
    } on LeaveException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Revisar solicitud'),
      ),
      body: Builder(
        builder: (context) {
          if (_loading) return const LoadingState();
          if (_error != null) {
            return ErrorState(message: _error!, onRetry: _load);
          }
          final r = _req!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.xxl,
            ),
            children: [
              Row(
                children: [
                  Icon(r.type.icon, color: AppColors.textPrimary, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text('Solicitud de ${r.type.label.toLowerCase()}',
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 18)),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              AppCard(
                child: Column(
                  children: [
                    _kv('Empleado', r.employee?.name ?? '--'),
                    if ((r.employee?.position ?? '').isNotEmpty)
                      _kv('Puesto', r.employee!.position!),
                    Divider(
                        color: AppColors.surfaceBorder, height: AppSpacing.xl),
                    _kv('Periodo solicitado', r.requestedRangeLabel),
                    _kv('Días solicitados', '${r.requestedDays}'),
                    if (r.approvedStart != null) ...[
                      Divider(
                          color: AppColors.surfaceBorder,
                          height: AppSpacing.xl),
                      _kv('Periodo autorizado', r.approvedRangeLabel,
                          highlight: true),
                      _kv('Días autorizados', '${r.approvedDays ?? '--'}',
                          highlight: true),
                    ],
                    Divider(
                        color: AppColors.surfaceBorder, height: AppSpacing.xl),
                    _kv('Estado', r.status.label),
                    _kv('Enviada', LeaveRequest.fmtDate(r.createdAt)),
                  ],
                ),
              ),
              if ((r.reason ?? '').isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                _note('Motivo', r.reason!),
              ],
              if ((r.rejectionReason ?? '').isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                _note('Motivo del rechazo', r.rejectionReason!,
                    color: AppColors.error),
              ],
              if ((r.cancellationReason ?? '').isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                _note('Motivo de la revocación', r.cancellationReason!,
                    color: AppColors.warning),
              ],
              if (r.hasEvidence) ...[
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: 'VER EVIDENCIA',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) =>
                            EvidenceViewer(url: LeaveApi.evidenceUrl(r.id))),
                  ),
                ),
              ],
              if (r.isPending && r.deptOverlaps.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.card),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: EdgeInsets.only(top: 1),
                            child: Icon(Icons.warning_amber_rounded,
                                size: 16, color: AppColors.warning),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${r.deptOverlaps.length} '
                              '${r.deptOverlaps.length == 1 ? 'persona del área ya tiene' : 'personas del área ya tienen'} '
                              'una ausencia que se cruza con estas fechas',
                              softWrap: true,
                              style: TextStyle(
                                  color: AppColors.warning,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      for (final o in r.deptOverlaps)
                        Text(
                          '• ${o.employeeName ?? 'Empleado'} — ${o.typeLabel} '
                          '(${o.statusLabel.toLowerCase()}) · ${o.rangeLabel}',
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 12),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              if (r.isPending)
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _busy ? null : _approve,
                        icon: const Icon(Icons.check),
                        label: const Text('APROBAR'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _reasonAction(
                                  title: 'Rechazar solicitud',
                                  hint: 'Motivo del rechazo',
                                  confirmLabel: 'CONFIRMAR RECHAZO',
                                  run: (reason) => LeaveApi.reject(
                                      widget.requestId,
                                      reason: reason),
                                  okMessage: 'Solicitud rechazada.',
                                ),
                        icon: const Icon(Icons.close),
                        label: const Text('RECHAZAR'),
                        style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error),
                      ),
                    ),
                  ],
                )
              else if (r.isApproved)
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _reasonAction(
                            title: 'Revocar permiso',
                            hint: 'Motivo de la revocación',
                            confirmLabel: 'CONFIRMAR REVOCACIÓN',
                            run: (reason) => LeaveApi.adminCancel(
                                widget.requestId,
                                reason: reason),
                            okMessage: 'Permiso revocado.',
                          ),
                  icon: const Icon(Icons.undo),
                  label: const Text('REVOCAR PERMISO'),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.warning),
                )
              else
                Text(
                  'Esta solicitud ya fue ${r.status.label.toLowerCase()}.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _kv(String k, String v, {bool highlight = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
                child: Text(k,
                    style:
                        TextStyle(color: AppColors.textMuted, fontSize: 13))),
            Expanded(
              child: Text(
                v,
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: highlight
                      ? AppColors.accentStrong
                      : AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _note(String title, String body, {Color? color}) => AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                  color: color ?? AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                )),
            const SizedBox(height: 4),
            Text(body,
                style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
          ],
        ),
      );
}
