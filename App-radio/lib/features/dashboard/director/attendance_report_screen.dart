import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/models/attendance.dart';
import 'package:doliv_social/models/models.dart';
import 'package:doliv_social/services/attendance_service.dart';
import 'package:doliv_social/services/team_service.dart';

/// Reporte mensual de asistencia para nómina. Muestra una vista previa por
/// empleado y permite exportar a CSV o PDF (los genera el backend); el
/// archivo se comparte por la hoja del sistema.
class AttendanceReportScreen extends StatefulWidget {
  const AttendanceReportScreen({super.key});

  @override
  State<AttendanceReportScreen> createState() => _AttendanceReportScreenState();
}

class _AttendanceReportScreenState extends State<AttendanceReportScreen> {
  late DateTime _month;
  List<DepartmentInfo> _departments = const [];
  String? _departmentId;

  List<AdminAttendanceSummaryRow> _rows = const [];
  AttendancePeriodSummary? _totals;
  bool _loading = true;
  bool _exporting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _init();
  }

  String get _monthParam =>
      '${_month.year.toString().padLeft(4, '0')}-${_month.month.toString().padLeft(2, '0')}';

  String get _monthLabel {
    const months = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
    ];
    return '${months[_month.month - 1]} ${_month.year}';
  }

  Future<void> _init() async {
    try {
      _departments = await TeamApi.listDepartments();
    } catch (_) {
      _departments = const []; // el manager no lista departamentos: sin filtro
    }
    await _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await AttendanceApi.adminSummary(
        month: _monthParam,
        departmentId: _departmentId,
      );
      if (!mounted) return;
      setState(() {
        _rows = res.rows;
        _totals = res.totals;
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

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year, now.month),
      initialDate: _month,
      helpText: 'Mes del reporte',
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null) {
      setState(() => _month = DateTime(picked.year, picked.month));
      _load();
    }
  }

  Future<void> _export(String format) async {
    setState(() => _exporting = true);
    try {
      final r = await AttendanceApi.downloadReport(
        format: format,
        month: _monthParam,
        departmentId: _departmentId,
      );
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${r.filename}');
      await file.writeAsBytes(r.bytes, flush: true);
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, mimeType: r.mime)],
        subject: 'Reporte de asistencia $_monthLabel',
        text: 'Reporte de asistencia de $_monthLabel.',
      ));
    } on AttendanceException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('No se pudo generar el archivo.');
    } finally {
      if (mounted) setState(() => _exporting = false);
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
          title: const Text('Reporte de asistencia')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
            child: Column(
              children: [
                _row(Icons.calendar_month, 'Mes', _monthLabel, _pickMonth),
                if (_departments.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  DropdownButtonFormField<String?>(
                    initialValue: _departmentId,
                    decoration: const InputDecoration(
                      prefixIcon:
                          Icon(Icons.groups_2_outlined, color: AppColors.accent),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('Todos los departamentos')),
                      for (final d in _departments)
                        DropdownMenuItem(value: d.id, child: Text(d.name)),
                    ],
                    onChanged: (v) {
                      setState(() => _departmentId = v);
                      _load();
                    },
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _exporting || _loading ? null : () => _export('csv'),
                        icon: const Icon(Icons.table_view, size: 18),
                        label: const Text('CSV'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _exporting || _loading ? null : () => _export('pdf'),
                        icon: _exporting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.picture_as_pdf, size: 18),
                        label: const Text('PDF'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const LoadingState()
                : _error != null
                    ? ErrorState(message: _error!, onRetry: _load)
                    : _rows.isEmpty
                        ? const EmptyState(
                            icon: Icons.assignment_outlined,
                            title: 'Sin datos',
                            message: 'No hay trabajadores en el alcance seleccionado.',
                          )
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(AppSpacing.lg,
                                AppSpacing.md, AppSpacing.lg, AppSpacing.xxl),
                            children: [
                              if (_totals != null) ...[
                                AppFadeIn(child: _totalCard(_totals!)),
                                const SizedBox(height: AppSpacing.lg),
                              ],
                              for (int i = 0; i < _rows.length; i++) ...[
                                AppFadeIn.staggered(
                                  index: i,
                                  child: _employeeCard(_rows[i]),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                              ],
                            ],
                          ),
          ),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String value, VoidCallback onTap) =>
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon, color: AppColors.accent),
        title: Text(label,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        subtitle: Text(value,
            style: const TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
        onTap: onTap,
      );

  Widget _totalCard(AttendancePeriodSummary t) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Totales del mes'),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: 1.8,
            children: [
              StatTile(
                icon: Icons.event_available_outlined,
                value: '${t.workedDays}',
                label: 'Días trabajados',
              ),
              StatTile(
                icon: Icons.schedule_outlined,
                value: t.totalLabel,
                label: 'Horas trabajadas',
              ),
              StatTile(
                icon: Icons.running_with_errors_outlined,
                value: '${t.lateCount}',
                label: 'Tardanzas',
                accentColor: AppColors.warning,
              ),
              StatTile(
                icon: Icons.event_busy_outlined,
                value: '${t.absentDays}',
                label: 'Faltas',
                accentColor: AppColors.error,
              ),
            ],
          ),
        ],
      );

  Widget _employeeCard(AdminAttendanceSummaryRow r) {
    final s = r.summary;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(r.name,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 15)),
          if ((r.position ?? '').isNotEmpty)
            Text(r.position!,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              AppBadge(label: '${s.workedDays}/${s.businessDays} días'),
              AppBadge(label: s.totalLabel),
              if (s.lateCount > 0)
                AppBadge(
                    label: '${s.lateCount} tarde',
                    variant: AppBadgeVariant.warning),
              if (s.absentDays > 0)
                AppBadge(
                    label: '${s.absentDays} faltas',
                    variant: AppBadgeVariant.error),
              if (s.vacationDays > 0) AppBadge(label: '${s.vacationDays} vac.'),
              if (s.incapacityDays > 0)
                AppBadge(label: '${s.incapacityDays} incap.'),
              if (s.permissionDays > 0)
                AppBadge(label: '${s.permissionDays} perm.'),
              if (s.onTimeRate != null)
                AppBadge(
                    label: '${s.onTimeRate}% punt.',
                    variant: AppBadgeVariant.info),
            ],
          ),
        ],
      ),
    );
  }
}
