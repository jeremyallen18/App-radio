import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/models/attendance.dart';
import 'package:doliv_social/models/models.dart';
import 'package:doliv_social/services/activities_report_service.dart';
import 'package:doliv_social/services/attendance_service.dart';
import 'package:doliv_social/services/team_service.dart';

/// Reportes del mes para dirección / manager: dos pestañas — **Asistencia**
/// (para nómina) y **Actividades** (tareas de departamento completadas). El
/// filtro de mes y departamento es común a ambas; los archivos CSV/PDF los
/// genera el backend y se comparten por la hoja del sistema.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late DateTime _month;
  List<DepartmentInfo> _departments = const [];
  String? _departmentId;

  // Asistencia
  List<AdminAttendanceSummaryRow> _attRows = const [];
  AttendancePeriodSummary? _attTotals;
  bool _attLoading = true;
  String? _attError;

  // Actividades
  List<ActivityRow> _actRows = const [];
  ActivityTotals? _actTotals;
  bool _actLoading = true;
  String? _actError;

  String? _exporting; // 'att-csv' | 'att-pdf' | 'act-csv' | 'act-pdf'

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
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
    ];
    return '${months[_month.month - 1]} ${_month.year}';
  }

  Future<void> _init() async {
    try {
      _departments = await TeamApi.listDepartments();
    } catch (_) {
      _departments = const []; // el manager no lista departamentos: sin filtro
    }
    await _loadAll();
  }

  Future<void> _loadAll() => Future.wait([_loadAttendance(), _loadActivities()]);

  Future<void> _loadAttendance() async {
    setState(() {
      _attLoading = true;
      _attError = null;
    });
    try {
      final res = await AttendanceApi.adminSummary(
        month: _monthParam,
        departmentId: _departmentId,
      );
      if (!mounted) return;
      setState(() {
        _attRows = res.rows;
        _attTotals = res.totals;
        _attLoading = false;
      });
    } on AttendanceException catch (e) {
      if (!mounted) return;
      setState(() {
        _attError = e.message;
        _attLoading = false;
      });
    }
  }

  Future<void> _loadActivities() async {
    setState(() {
      _actLoading = true;
      _actError = null;
    });
    try {
      final res = await ActivitiesReportApi.summary(
        month: _monthParam,
        departmentId: _departmentId,
      );
      if (!mounted) return;
      setState(() {
        _actRows = res.rows;
        _actTotals = res.totals;
        _actLoading = false;
      });
    } on AttendanceException catch (e) {
      if (!mounted) return;
      setState(() {
        _actError = e.message;
        _actLoading = false;
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
      _loadAll();
    }
  }

  Future<void> _shareFile(
    ({List<int> bytes, String filename, String mime}) r,
    String subject,
  ) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${r.filename}');
    await file.writeAsBytes(r.bytes, flush: true);
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: r.mime)],
      subject: subject,
      text: subject,
    ));
  }

  Future<void> _exportAttendance(String format) async {
    setState(() => _exporting = 'att-$format');
    try {
      final r = await AttendanceApi.downloadReport(
        format: format,
        month: _monthParam,
        departmentId: _departmentId,
      );
      await _shareFile(r, 'Reporte de asistencia $_monthLabel');
    } on AttendanceException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('No se pudo generar el archivo.');
    } finally {
      if (mounted) setState(() => _exporting = null);
    }
  }

  Future<void> _exportActivities(String format) async {
    setState(() => _exporting = 'act-$format');
    try {
      final r = await ActivitiesReportApi.downloadReport(
        format: format,
        month: _monthParam,
        departmentId: _departmentId,
      );
      await _shareFile(r, 'Reporte de actividades $_monthLabel');
    } on AttendanceException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('No se pudo generar el archivo.');
    } finally {
      if (mounted) setState(() => _exporting = null);
    }
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  bool get _busy => _exporting != null;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialTab.clamp(0, 1),
      child: AppScaffold(
        padding: EdgeInsets.zero,
        appBar: AppBar(
          leading: const BackButton(),
          title: const Text('Reportes del mes'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Asistencia'),
              Tab(text: 'Actividades'),
            ],
          ),
        ),
        body: Column(
          children: [
            _FilterCard(
              monthLabel: _monthLabel,
              onPickMonth: _pickMonth,
              departments: _departments,
              departmentId: _departmentId,
              onDepartmentChanged: (v) {
                setState(() => _departmentId = v);
                _loadAll();
              },
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _AttendanceTab(
                    loading: _attLoading,
                    error: _attError,
                    rows: _attRows,
                    totals: _attTotals,
                    exportingCsv: _exporting == 'att-csv',
                    exportingPdf: _exporting == 'att-pdf',
                    exportEnabled: !_busy && !_attLoading,
                    onRetry: _loadAttendance,
                    onExportCsv: () => _exportAttendance('csv'),
                    onExportPdf: () => _exportAttendance('pdf'),
                  ),
                  _ActivitiesTab(
                    loading: _actLoading,
                    error: _actError,
                    rows: _actRows,
                    totals: _actTotals,
                    exportingCsv: _exporting == 'act-csv',
                    exportingPdf: _exporting == 'act-pdf',
                    exportEnabled: !_busy && !_actLoading,
                    onRetry: _loadActivities,
                    onExportCsv: () => _exportActivities('csv'),
                    onExportPdf: () => _exportActivities('pdf'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta de filtros común a ambas pestañas: mes y (para el director) el
/// departamento.
class _FilterCard extends StatelessWidget {
  const _FilterCard({
    required this.monthLabel,
    required this.onPickMonth,
    required this.departments,
    required this.departmentId,
    required this.onDepartmentChanged,
  });

  final String monthLabel;
  final VoidCallback onPickMonth;
  final List<DepartmentInfo> departments;
  final String? departmentId;
  final ValueChanged<String?> onDepartmentChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
      child: AppCard(
        child: Column(
          children: [
            InkWell(
              onTap: onPickMonth,
              borderRadius: BorderRadius.circular(AppRadius.chip),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(
                  children: [
                    Icon(Icons.calendar_month, color: AppColors.accent, size: 20),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Mes',
                              style: TextStyle(
                                  color: AppColors.textMuted, fontSize: 11)),
                          Text(
                            monthLabel[0].toUpperCase() + monthLabel.substring(1),
                            style: TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.edit_calendar_outlined,
                        color: AppColors.textMuted, size: 18),
                  ],
                ),
              ),
            ),
            if (departments.isNotEmpty) ...[
              Divider(color: AppColors.surfaceBorder, height: AppSpacing.lg),
              DropdownButtonFormField<String?>(
                initialValue: departmentId,
                isExpanded: true,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.groups_2_outlined),
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(
                      value: null, child: Text('Todos los departamentos')),
                  for (final d in departments)
                    DropdownMenuItem(value: d.id, child: Text(d.name)),
                ],
                onChanged: onDepartmentChanged,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Fila "Exportar  [CSV] [PDF]" que encabeza cada pestaña.
class _ExportRow extends StatelessWidget {
  const _ExportRow({
    required this.enabled,
    required this.exportingCsv,
    required this.exportingPdf,
    required this.onCsv,
    required this.onPdf,
  });

  final bool enabled;
  final bool exportingCsv;
  final bool exportingPdf;
  final VoidCallback onCsv;
  final VoidCallback onPdf;

  @override
  Widget build(BuildContext context) {
    Widget spinner() => const SizedBox(
        width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2));
    return Row(
      children: [
        Text('Exportar',
            style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: enabled && !exportingCsv ? onCsv : null,
            icon: exportingCsv
                ? spinner()
                : const Icon(Icons.table_view, size: 18),
            label: const Text('CSV'),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: FilledButton.icon(
            onPressed: enabled && !exportingPdf ? onPdf : null,
            icon: exportingPdf
                ? spinner()
                : const Icon(Icons.picture_as_pdf, size: 18),
            label: const Text('PDF'),
          ),
        ),
      ],
    );
  }
}

/// Rejilla de `StatTile` de 2 por fila que se adapta al ancho.
class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.tiles});

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        const gap = AppSpacing.sm;
        final w = (c.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final t in tiles) SizedBox(width: w, child: t),
          ],
        );
      },
    );
  }
}

class _AttendanceTab extends StatelessWidget {
  const _AttendanceTab({
    required this.loading,
    required this.error,
    required this.rows,
    required this.totals,
    required this.exportingCsv,
    required this.exportingPdf,
    required this.exportEnabled,
    required this.onRetry,
    required this.onExportCsv,
    required this.onExportPdf,
  });

  final bool loading;
  final String? error;
  final List<AdminAttendanceSummaryRow> rows;
  final AttendancePeriodSummary? totals;
  final bool exportingCsv;
  final bool exportingPdf;
  final bool exportEnabled;
  final VoidCallback onRetry;
  final VoidCallback onExportCsv;
  final VoidCallback onExportPdf;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xxl),
      children: [
        _ExportRow(
          enabled: exportEnabled,
          exportingCsv: exportingCsv,
          exportingPdf: exportingPdf,
          onCsv: onExportCsv,
          onPdf: onExportPdf,
        ),
        const SizedBox(height: AppSpacing.lg),
        if (loading)
          const Padding(
            padding: EdgeInsets.only(top: AppSpacing.xxl),
            child: LoadingState(),
          )
        else if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xl),
            child: ErrorState(message: error!, onRetry: onRetry),
          )
        else if (rows.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: AppSpacing.xxl),
            child: EmptyState(
              icon: Icons.assignment_outlined,
              title: 'Sin datos',
              message: 'No hay trabajadores en el alcance seleccionado.',
            ),
          )
        else ...[
          if (totals != null) ...[
            const SectionHeader(title: 'Totales del mes'),
            AppFadeIn(child: _totals(totals!)),
            const SizedBox(height: AppSpacing.lg),
          ],
          const SectionHeader(title: 'Por persona'),
          for (int i = 0; i < rows.length; i++) ...[
            AppFadeIn.staggered(index: i, child: _personCard(rows[i])),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ],
    );
  }

  Widget _totals(AttendancePeriodSummary t) => _StatGrid(
        tiles: [
          StatTile(
              icon: Icons.event_available_outlined,
              value: '${t.workedDays}',
              label: 'Días trabajados'),
          StatTile(
              icon: Icons.schedule_outlined,
              value: t.totalLabel,
              label: 'Horas trabajadas'),
          StatTile(
              icon: Icons.running_with_errors_outlined,
              value: '${t.lateCount}',
              label: 'Tardanzas',
              accentColor: AppColors.warning),
          StatTile(
              icon: Icons.event_busy_outlined,
              value: '${t.absentDays}',
              label: 'Faltas',
              accentColor: AppColors.error),
        ],
      );

  Widget _personCard(AdminAttendanceSummaryRow r) {
    final s = r.summary;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _personHeader(
            r.name,
            r.position,
            trailingValue: '${s.workedDays}/${s.businessDays}',
            trailingLabel: 'días',
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
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

class _ActivitiesTab extends StatelessWidget {
  const _ActivitiesTab({
    required this.loading,
    required this.error,
    required this.rows,
    required this.totals,
    required this.exportingCsv,
    required this.exportingPdf,
    required this.exportEnabled,
    required this.onRetry,
    required this.onExportCsv,
    required this.onExportPdf,
  });

  final bool loading;
  final String? error;
  final List<ActivityRow> rows;
  final ActivityTotals? totals;
  final bool exportingCsv;
  final bool exportingPdf;
  final bool exportEnabled;
  final VoidCallback onRetry;
  final VoidCallback onExportCsv;
  final VoidCallback onExportPdf;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xxl),
      children: [
        _ExportRow(
          enabled: exportEnabled,
          exportingCsv: exportingCsv,
          exportingPdf: exportingPdf,
          onCsv: onExportCsv,
          onPdf: onExportPdf,
        ),
        const SizedBox(height: AppSpacing.lg),
        if (loading)
          const Padding(
            padding: EdgeInsets.only(top: AppSpacing.xxl),
            child: LoadingState(),
          )
        else if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xl),
            child: ErrorState(message: error!, onRetry: onRetry),
          )
        else if (rows.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: AppSpacing.xxl),
            child: EmptyState(
              icon: Icons.checklist_rtl,
              title: 'Sin actividades',
              message:
                  'Nadie completó tareas de departamento en el mes y alcance elegidos.',
            ),
          )
        else ...[
          if (totals != null) ...[
            const SectionHeader(title: 'Totales del mes'),
            AppFadeIn(child: _totals(totals!)),
            const SizedBox(height: AppSpacing.lg),
          ],
          const SectionHeader(title: 'Por persona'),
          for (int i = 0; i < rows.length; i++) ...[
            AppFadeIn.staggered(index: i, child: _personCard(rows[i])),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ],
    );
  }

  Widget _totals(ActivityTotals t) => _StatGrid(
        tiles: [
          StatTile(
              icon: Icons.task_alt_outlined,
              value: '${t.completed}',
              label: 'Tareas completadas'),
          StatTile(
              icon: Icons.people_alt_outlined,
              value: '${t.people}',
              label: 'Personas activas'),
          StatTile(
              icon: Icons.verified_outlined,
              value: '${t.onTime}',
              label: 'A tiempo',
              accentColor: AppColors.success),
          StatTile(
              icon: Icons.running_with_errors_outlined,
              value: '${t.late}',
              label: 'Con retardo',
              accentColor: AppColors.warning),
        ],
      );

  Widget _personCard(ActivityRow r) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _personHeader(
            r.name,
            r.position,
            trailingValue: '${r.completed}',
            trailingLabel: r.completed == 1 ? 'tarea' : 'tareas',
          ),
          if (r.onTime > 0 || r.late > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                if (r.onTime > 0)
                  AppBadge(
                      label: '${r.onTime} a tiempo',
                      variant: AppBadgeVariant.success),
                if (r.late > 0)
                  AppBadge(
                      label: '${r.late} retardo',
                      variant: AppBadgeVariant.warning),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Encabezado de una tarjeta por persona: nombre + puesto a la izquierda, y una
/// métrica principal (valor grande + etiqueta) a la derecha.
Widget _personHeader(
  String name,
  String? position, {
  required String trailingValue,
  required String trailingLabel,
}) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name,
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15)),
            if ((position ?? '').isNotEmpty)
              Text(position!,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ],
        ),
      ),
      const SizedBox(width: AppSpacing.sm),
      Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(trailingValue,
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 18)),
          Text(trailingLabel,
              style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
        ],
      ),
    ],
  );
}
