import 'package:flutter/material.dart';

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/models/leave_request.dart';
import 'package:doliv_social/services/leave_service.dart';
import 'package:doliv_social/features/dashboard/director/admin_leave_review_screen.dart';

/// "Gestión de permisos" (director): pestañas Pendientes / Aprobados /
/// Rechazados / Cancelados, con filtro opcional por tipo.
class AdminLeaveScreen extends StatefulWidget {
  const AdminLeaveScreen({super.key});

  @override
  State<AdminLeaveScreen> createState() => _AdminLeaveScreenState();
}

class _AdminLeaveScreenState extends State<AdminLeaveScreen>
    with SingleTickerProviderStateMixin {
  static const _tabs = [
    (LeaveStatus.pendiente, 'Pendientes'),
    (LeaveStatus.aprobado, 'Aprobados'),
    (LeaveStatus.rechazado, 'Rechazados'),
    (LeaveStatus.cancelado, 'Cancelados'),
  ];

  late final TabController _tab;
  LeaveType? _typeFilter;

  List<LeaveRequest> _items = const [];
  bool _loading = true;
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
      final items = await LeaveApi.adminList(
        status: _tabs[_tab.index].$1,
        type: _typeFilter,
      );
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

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Gestión de permisos'),
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [for (final t in _tabs) Tab(text: t.$2)],
        ),
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                AppFilterChip(
                  label: 'Todos',
                  selected: _typeFilter == null,
                  onTap: () {
                    setState(() => _typeFilter = null);
                    _load();
                  },
                ),
                for (final t in LeaveType.values) ...[
                  const SizedBox(width: AppSpacing.sm),
                  AppFilterChip(
                    label: t.label,
                    selected: _typeFilter == t,
                    onTap: () {
                      setState(() => _typeFilter = t);
                      _load();
                    },
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: Builder(
              builder: (context) {
                if (_loading) return const LoadingState();
                if (_error != null) return ErrorState(message: _error!, onRetry: _load);
                if (_items.isEmpty) {
                  return const EmptyState(
                    icon: Icons.inbox_outlined,
                    title: 'No hay solicitudes en esta sección',
                  );
                }
                return RefreshIndicator(
                  color: AppColors.accent,
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xxl,
                    ),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
                    itemBuilder: (_, i) => _AdminLeaveCard(
                      request: _items[i],
                      onReview: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => AdminLeaveReviewScreen(requestId: _items[i].id),
                          ),
                        );
                        _load();
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminLeaveCard extends StatelessWidget {
  const _AdminLeaveCard({required this.request, required this.onReview});
  final LeaveRequest request;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final r = request;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            r.employee?.name ?? 'Empleado',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(r.type.icon, size: 14, color: AppColors.textPrimary),
              const SizedBox(width: 4),
              Text(r.type.label,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            r.status == LeaveStatus.aprobado ? r.approvedRangeLabel : r.requestedRangeLabel,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text('Estado: ${r.status.label}',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          if (r.hasEvidence) ...[
            const SizedBox(height: 4),
            Row(
              children: const [
                Icon(Icons.attach_file, size: 13, color: AppColors.accent),
                SizedBox(width: 4),
                Text('Evidencia adjunta',
                    style: TextStyle(color: AppColors.accent, fontSize: 12)),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: onReview,
              child: const Text('REVISAR'),
            ),
          ),
        ],
      ),
    );
  }
}
