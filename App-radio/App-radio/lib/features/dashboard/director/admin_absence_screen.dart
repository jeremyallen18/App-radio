import 'package:flutter/material.dart';

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/services/absence_service.dart';
import 'package:doliv_social/services/leave_service.dart' show LeaveException;
import 'package:doliv_social/features/dashboard/director/leave_review_sheets.dart';
import 'package:doliv_social/shared/widgets/evidence_viewer.dart';

/// "Justificaciones de faltas" (director): revisa lo que envían los
/// trabajadores para justificar sus faltas y las aprueba o rechaza. Una
/// justificación aprobada quita esos días del conteo de faltas injustificadas.
class AdminAbsenceScreen extends StatefulWidget {
  const AdminAbsenceScreen({super.key});

  @override
  State<AdminAbsenceScreen> createState() => _AdminAbsenceScreenState();
}

class _AdminAbsenceScreenState extends State<AdminAbsenceScreen>
    with SingleTickerProviderStateMixin {
  static const _tabs = [
    ('pendiente', 'Pendientes'),
    ('aprobada', 'Aprobadas'),
    ('rechazada', 'Rechazadas'),
  ];

  late final TabController _tab;
  List<AdminAbsenceJustification> _items = const [];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _tabs.length, vsync: this)
      ..addListener(() {
        if (!_tab.indexIsChanging) _load();
      });
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await AbsenceApi.adminList(status: _tabs[_tab.index].$1);
      if (!mounted) return;
      setState(() {
        _items = items;
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

  Future<void> _approve(AdminAbsenceJustification j) async {
    setState(() => _busy = true);
    try {
      await AbsenceApi.adminApprove(j.item.id);
      _snack('Justificación aprobada.');
      await _load();
    } on LeaveException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject(AdminAbsenceJustification j) async {
    final reason = await showLeaveReasonSheet(
      context,
      title: 'Rechazar justificación',
      hint: 'Motivo del rechazo',
      confirmLabel: 'CONFIRMAR RECHAZO',
    );
    if (reason == null || reason.isEmpty) return;
    setState(() => _busy = true);
    try {
      await AbsenceApi.adminReject(j.item.id, reason: reason);
      _snack('Justificación rechazada.');
      await _load();
    } on LeaveException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Justificaciones de faltas'),
        bottom: TabBar(
          controller: _tab,
          tabs: [for (final t in _tabs) Tab(text: t.$2)],
        ),
      ),
      body: Builder(
        builder: (context) {
          if (_loading) return const LoadingState();
          if (_error != null) {
            return ErrorState(message: _error!, onRetry: _load);
          }
          if (_items.isEmpty) {
            return const EmptyState(
              icon: Icons.fact_check_outlined,
              title: 'Nada por aquí',
              message: 'No hay justificaciones en este estado.',
            );
          }
          return RefreshIndicator(
            color: AppColors.accent,
            onRefresh: _load,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
              itemCount: _items.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.md),
              itemBuilder: (_, i) => _Card(
                data: _items[i],
                busy: _busy,
                onApprove: () => _approve(_items[i]),
                onReject: () => _reject(_items[i]),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.data,
    required this.busy,
    required this.onApprove,
    required this.onReject,
  });
  final AdminAbsenceJustification data;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  String _d(DateTime x) =>
      '${x.day.toString().padLeft(2, '0')}/${x.month.toString().padLeft(2, '0')}/${x.year}';

  @override
  Widget build(BuildContext context) {
    final j = data.item;
    final range =
        j.start == j.end ? _d(j.start) : '${_d(j.start)} — ${_d(j.end)}';
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(data.employeeName,
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 15)),
              ),
              Text(j.statusLabel,
                  style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 2),
          Text('Falta: $range',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          if ((j.reason ?? '').isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(j.reason!,
                style: TextStyle(color: AppColors.textPrimary, fontSize: 13)),
          ],
          if (j.hasEvidence) ...[
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      EvidenceViewer(url: AbsenceApi.evidenceUrl(j.id)),
                ),
              ),
              icon: const Icon(Icons.attach_file, size: 16),
              label: const Text('Ver evidencia'),
            ),
          ],
          if (j.status == 'pendiente') ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: busy ? null : onApprove,
                    icon: const Icon(Icons.check),
                    label: const Text('APROBAR'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : onReject,
                    icon: const Icon(Icons.close),
                    label: const Text('RECHAZAR'),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error),
                  ),
                ),
              ],
            ),
          ] else if ((j.reviewNote ?? '').isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text('Motivo: ${j.reviewNote}',
                style: TextStyle(color: AppColors.error, fontSize: 12)),
          ],
        ],
      ),
    );
  }
}
