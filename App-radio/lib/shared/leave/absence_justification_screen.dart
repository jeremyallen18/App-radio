import 'dart:io';

import 'package:flutter/material.dart';

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/services/absence_service.dart';
import 'package:doliv_social/services/leave_service.dart' show LeaveException;
import 'package:doliv_social/shared/leave/evidence_picker.dart';
import 'package:doliv_social/shared/widgets/evidence_viewer.dart';

/// Justificación de faltas pasadas: el trabajador ve sus faltas (días
/// laborales lun-sáb ya pasados sin asistencia ni permiso) y envía una
/// justificación con motivo y evidencia OBLIGATORIA. El director la aprueba
/// o la rechaza; una aprobada deja de contar como falta injustificada.
class AbsenceJustificationScreen extends StatefulWidget {
  const AbsenceJustificationScreen({super.key});

  @override
  State<AbsenceJustificationScreen> createState() =>
      _AbsenceJustificationScreenState();
}

class _AbsenceJustificationScreenState
    extends State<AbsenceJustificationScreen> {
  AbsencesResult? _data;
  bool _loading = true;
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
      final data = await AbsenceApi.mine();
      if (!mounted) return;
      setState(() {
        _data = data;
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

  Future<void> _startJustification(AbsenceRun run) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (_) => _JustifySheet(run: run),
    );
    if (ok == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Justificar faltas'),
      ),
      body: Builder(
        builder: (context) {
          if (_loading) return const LoadingState();
          if (_error != null) return ErrorState(message: _error!, onRetry: _load);
          final data = _data!;
          if (data.unjustified.isEmpty && data.justifications.isEmpty) {
            return const EmptyState(
              icon: Icons.event_available_outlined,
              title: 'No tienes faltas por justificar',
              message:
                  'Aquí aparecerán los días laborales sin asistencia ni permiso.',
            );
          }
          return RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
              children: [
                if (data.unjustified.isNotEmpty) ...[
                  const SectionHeader(title: 'Faltas por justificar'),
                  const Text(
                    'Toda justificación requiere evidencia (foto o PDF).',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  for (final run in data.unjustified) ...[
                    _RunCard(run: run, onJustify: () => _startJustification(run)),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                ],
                if (data.justifications.isNotEmpty) ...[
                  const SectionHeader(title: 'Mis justificaciones'),
                  for (final j in data.justifications) ...[
                    _JustificationCard(item: j),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

String _range(DateTime a, DateTime b) {
  String d(DateTime x) =>
      '${x.day.toString().padLeft(2, '0')}/${x.month.toString().padLeft(2, '0')}/${x.year}';
  return a == b ? d(a) : '${d(a)} — ${d(b)}';
}

class _RunCard extends StatelessWidget {
  const _RunCard({required this.run, required this.onJustify});
  final AbsenceRun run;
  final VoidCallback onJustify;

  @override
  Widget build(BuildContext context) {
    final status = run.justificationStatus;
    final (String label, AppBadgeVariant variant)? badge = switch (status) {
      'pendiente' => ('En revisión', AppBadgeVariant.info),
      'aprobada' => ('Justificada', AppBadgeVariant.success),
      'rechazada' => ('Rechazada', AppBadgeVariant.error),
      _ => null,
    };
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.event_busy_outlined,
                  size: 18, color: AppColors.warning),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  _range(run.start, run.end),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              if (badge != null)
                AppBadge(label: badge.$1, variant: badge.$2),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            run.days == 1
                ? '1 día laboral sin asistencia'
                : '${run.days} días laborales consecutivos sin asistencia',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          if (run.canSubmit) ...[
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: status == 'rechazada'
                  ? 'VOLVER A JUSTIFICAR'
                  : 'JUSTIFICAR',
              onPressed: onJustify,
            ),
          ],
        ],
      ),
    );
  }
}

class _JustificationCard extends StatelessWidget {
  const _JustificationCard({required this.item});
  final AbsenceJustification item;

  @override
  Widget build(BuildContext context) {
    final color = switch (item.status) {
      'aprobada' => AppColors.success,
      'rechazada' => AppColors.error,
      _ => AppColors.warning,
    };
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _range(item.start, item.end),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              Text(item.statusLabel,
                  style: TextStyle(
                      color: color, fontSize: 12, fontWeight: FontWeight.w700)),
            ],
          ),
          if ((item.reason ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(item.reason!,
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 12)),
          ],
          if ((item.reviewNote ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Nota del director: ${item.reviewNote}',
                style: const TextStyle(color: AppColors.error, fontSize: 12)),
          ],
          if (item.hasEvidence) ...[
            const SizedBox(height: AppSpacing.sm),
            TextButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      EvidenceViewer(url: AbsenceApi.evidenceUrl(item.id)),
                ),
              ),
              icon: const Icon(Icons.attach_file, size: 16),
              label: const Text('Ver evidencia'),
            ),
          ],
        ],
      ),
    );
  }
}

class _JustifySheet extends StatefulWidget {
  const _JustifySheet({required this.run});
  final AbsenceRun run;

  @override
  State<_JustifySheet> createState() => _JustifySheetState();
}

class _JustifySheetState extends State<_JustifySheet> {
  final _reason = TextEditingController();
  File? _evidence;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_evidence == null) {
      setState(() => _error = 'Debes adjuntar evidencia para justificar la falta.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await AbsenceApi.justify(
        start: widget.run.start,
        end: widget.run.end,
        reason: _reason.text,
        evidence: _evidence!,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
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
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Justificar ${_range(widget.run.start, widget.run.end)}',
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 16),
            ),
            const SizedBox(height: AppSpacing.md),
            const Text('Motivo (opcional)',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              controller: _reason,
              hintText: 'Explica por qué faltaste',
              maxLines: 3,
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text('Evidencia (obligatoria)',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
            const SizedBox(height: AppSpacing.sm),
            EvidencePicker(
              file: _evidence,
              onPicked: (f) => setState(() => _evidence = f),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(_error!,
                  style: const TextStyle(color: AppColors.error, fontSize: 12)),
            ],
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'ENVIAR JUSTIFICACIÓN',
              loading: _submitting,
              onPressed: _submitting ? null : _submit,
            ),
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: TextButton(
                onPressed: _submitting ? null : () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
