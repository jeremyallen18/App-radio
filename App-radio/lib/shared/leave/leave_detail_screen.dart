import 'package:flutter/material.dart';

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/models/leave_request.dart';
import 'package:doliv_social/services/leave_service.dart';
import 'package:doliv_social/shared/widgets/evidence_viewer.dart';

/// Vista de una solicitud propia del empleado: fechas solicitadas y aprobadas,
/// estado, motivo de rechazo/cancelación y evidencia. Puede cancelarla si
/// sigue pendiente.
class LeaveDetailScreen extends StatefulWidget {
  const LeaveDetailScreen({super.key, required this.requestId});
  final String requestId;

  @override
  State<LeaveDetailScreen> createState() => _LeaveDetailScreenState();
}

class _LeaveDetailScreenState extends State<LeaveDetailScreen> {
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
      final r = await LeaveApi.get(widget.requestId);
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

  Future<void> _cancel() async {
    final ok = await showAppConfirmDialog(
      context,
      title: 'Cancelar solicitud',
      message: '¿Seguro que quieres cancelar esta solicitud?',
      confirmLabel: 'Sí, cancelar',
      danger: true,
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      final r = await LeaveApi.cancelMine(widget.requestId);
      if (!mounted) return;
      setState(() {
        _req = r;
        _busy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitud cancelada.')),
      );
    } on LeaveException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Detalle de la solicitud'),
      ),
      body: Builder(
        builder: (context) {
          if (_loading) return const LoadingState();
          if (_error != null) return ErrorState(message: _error!, onRetry: _load);
          final r = _req!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl,
            ),
            children: [
              Row(
                children: [
                  Icon(r.type.icon, size: 22, color: AppColors.textPrimary),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    r.type.label,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  const Spacer(),
                  _StatusBadge(status: r.status),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              AppCard(
                child: Column(
                  children: [
                    _kv('Periodo solicitado', r.requestedRangeLabel),
                    _kv('Días solicitados', '${r.requestedDays}'),
                    if (r.approvedStart != null) ...[
                      const Divider(color: AppColors.surfaceBorder, height: AppSpacing.xl),
                      _kv('Periodo autorizado', r.approvedRangeLabel, highlight: true),
                      _kv('Días autorizados', '${r.approvedDays ?? '--'}', highlight: true),
                    ],
                    const Divider(color: AppColors.surfaceBorder, height: AppSpacing.xl),
                    _kv('Enviada', LeaveRequest.fmtDate(r.createdAt)),
                    if (r.approvedAt != null)
                      _kv('Decisión', LeaveRequest.fmtDate(r.approvedAt)),
                    if (r.cancelledAt != null)
                      _kv('Cancelada', LeaveRequest.fmtDate(r.cancelledAt)),
                  ],
                ),
              ),
              if ((r.reason ?? '').isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                _NoteCard(title: 'Motivo', body: r.reason!),
              ],
              if ((r.rejectionReason ?? '').isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                _NoteCard(
                  title: 'Motivo del rechazo',
                  body: r.rejectionReason!,
                  color: AppColors.error,
                ),
              ],
              if ((r.cancellationReason ?? '').isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                _NoteCard(
                  title: 'Motivo de la cancelación',
                  body: r.cancellationReason!,
                  color: AppColors.warning,
                ),
              ],
              if (r.hasEvidence) ...[
                const SizedBox(height: AppSpacing.lg),
                AppCard(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => EvidenceViewer(url: LeaveApi.evidenceUrl(r.id)),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.attachment, color: AppColors.accent),
                      SizedBox(width: AppSpacing.md),
                      Expanded(child: Text('Ver evidencia adjunta',
                          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600))),
                      Icon(Icons.chevron_right, color: AppColors.textMuted),
                    ],
                  ),
                ),
              ],
              if (r.isPending) ...[
                const SizedBox(height: AppSpacing.xl),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _cancel,
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Cancelar solicitud'),
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _kv(String k, String v, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(k, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
          ),
          Expanded(
            child: Text(
              v,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: highlight ? AppColors.accentStrong : AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final LeaveStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      LeaveStatus.pendiente => AppColors.warning,
      LeaveStatus.aprobado => AppColors.success,
      LeaveStatus.rechazado => AppColors.error,
      LeaveStatus.cancelado => AppColors.textMuted,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        status.label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.title, required this.body, this.color});
  final String title;
  final String body;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: color ?? AppColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(body, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
        ],
      ),
    );
  }
}
