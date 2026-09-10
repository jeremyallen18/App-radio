import 'package:flutter/material.dart';

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/models/attendance.dart';
import 'package:doliv_social/services/attendance_service.dart';

/// Bandeja del director / manager para revisar las solicitudes de corrección
/// de asistencia de sus trabajadores. Aprobar aplica el cambio en el
/// historial; devolver pide un motivo.
class AttendanceCorrectionsScreen extends StatefulWidget {
  const AttendanceCorrectionsScreen({super.key});

  @override
  State<AttendanceCorrectionsScreen> createState() =>
      _AttendanceCorrectionsScreenState();
}

class _AttendanceCorrectionsScreenState
    extends State<AttendanceCorrectionsScreen> {
  CorrectionStatus? _filter = CorrectionStatus.pendiente;
  List<AttendanceCorrection> _items = const [];
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
      final items = await AttendanceApi.adminCorrections(status: _filter);
      if (!mounted) return;
      setState(() {
        _items = items;
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

  Future<void> _resolve(AttendanceCorrection c, {required bool approve}) async {
    String? note;
    if (!approve) {
      final controller = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Devolver solicitud'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'Motivo del rechazo'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancelar',
                  style: TextStyle(color: AppColors.textMuted)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Devolver', style: TextStyle(color: AppColors.error)),
            ),
          ],
        ),
      );
      if (ok != true) return;
      note = controller.text.trim();
      if (note.isEmpty) {
        _snack('Indica el motivo del rechazo.');
        return;
      }
    }
    setState(() => _busy = true);
    try {
      await AttendanceApi.resolveCorrection(c.id, approve: approve, note: note);
      await _load();
      if (mounted) setState(() => _busy = false);
    } on AttendanceException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack(e.message);
    }
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
          leading: const BackButton(),
          title: const Text('Correcciones de asistencia')),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
            child: Row(
              children: [
                _chip('Pendientes', CorrectionStatus.pendiente),
                const SizedBox(width: AppSpacing.sm),
                _chip('Aprobadas', CorrectionStatus.aprobado),
                const SizedBox(width: AppSpacing.sm),
                _chip('Rechazadas', CorrectionStatus.rechazado),
                const SizedBox(width: AppSpacing.sm),
                _chip('Todas', null),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const LoadingState()
                : _error != null
                    ? ErrorState(message: _error!, onRetry: _load)
                    : RefreshIndicator(
                        color: AppColors.accent,
                        onRefresh: _load,
                        child: _items.isEmpty
                            ? ListView(
                                children: const [
                                  Padding(
                                    padding:
                                        EdgeInsets.only(top: AppSpacing.xxl),
                                    child: EmptyState(
                                      icon: Icons.fact_check_outlined,
                                      title: 'Sin solicitudes',
                                      message:
                                          'No hay solicitudes en este filtro.',
                                    ),
                                  ),
                                ],
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                    AppSpacing.lg,
                                    AppSpacing.md,
                                    AppSpacing.lg,
                                    AppSpacing.xxl),
                                itemCount: _items.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: AppSpacing.sm),
                                itemBuilder: (_, i) => _tile(_items[i]),
                              ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, CorrectionStatus? value) => AppFilterChip(
        label: label,
        selected: _filter == value,
        onTap: () {
          setState(() => _filter = value);
          _load();
        },
      );

  Widget _tile(AttendanceCorrection c) {
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
                child: Text(c.employeeName ?? 'Empleado',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 14)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(c.status.label,
                    style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('${c.kindLabel} · ${c.workDateLabel} → ${c.requestedTime}',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 13)),
          const SizedBox(height: 2),
          Text(c.reason,
              style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          if ((c.reviewNote ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Nota: ${c.reviewNote}',
                style: TextStyle(color: color, fontSize: 12)),
          ],
          if (c.status == CorrectionStatus.pendiente) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : () => _resolve(c, approve: false),
                    icon: const Icon(Icons.undo, size: 16),
                    label: const Text('Devolver'),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy ? null : () => _resolve(c, approve: true),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Aprobar'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
