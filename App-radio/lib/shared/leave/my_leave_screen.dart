import 'package:flutter/material.dart';

import 'package:doliv_social/core/route_refresh.dart';
import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/models/leave_request.dart';
import 'package:doliv_social/services/leave_service.dart';
import 'package:doliv_social/shared/leave/absence_justification_screen.dart';
import 'package:doliv_social/shared/leave/leave_detail_screen.dart';
import 'package:doliv_social/shared/leave/leave_form_screen.dart';

/// "Mis permisos": historial de solicitudes propias del empleado. Punto de
/// entrada para crear una nueva.
class MyLeaveScreen extends StatefulWidget {
  const MyLeaveScreen({super.key});

  @override
  State<MyLeaveScreen> createState() => _MyLeaveScreenState();
}

class _MyLeaveScreenState extends State<MyLeaveScreen>
    with RouteAwareRefresh<MyLeaveScreen> {
  List<LeaveRequest> _items = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void onRouteReenter() => _load();

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await LeaveApi.mine();
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

  Future<void> _openForm() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const LeaveFormScreen()),
    );
    if (created == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Mis permisos'),
        actions: [
          IconButton(
            tooltip: 'Justificar faltas',
            icon: const Icon(Icons.event_busy_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const AbsenceJustificationScreen(),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openForm,
        icon: const Icon(Icons.add),
        label: const Text('Solicitar permiso'),
      ),
      body: Builder(
        builder: (context) {
          if (_loading) return const LoadingState();
          if (_error != null) return ErrorState(message: _error!, onRetry: _load);
          if (_items.isEmpty) {
            return const EmptyState(
              icon: Icons.beach_access_outlined,
              title: 'Aún no tienes solicitudes',
              message: 'Toca "Solicitar permiso" para crear la primera.',
            );
          }
          return RefreshIndicator(
            onRefresh: _load,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 96,
              ),
              itemCount: _items.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (_, i) => _LeaveCard(
                request: _items[i],
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => LeaveDetailScreen(requestId: _items[i].id),
                    ),
                  );
                  _load();
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LeaveCard extends StatelessWidget {
  const _LeaveCard({required this.request, required this.onTap});
  final LeaveRequest request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = request;
    final color = switch (r.status) {
      LeaveStatus.pendiente => AppColors.warning,
      LeaveStatus.aprobado => AppColors.success,
      LeaveStatus.rechazado => AppColors.error,
      LeaveStatus.cancelado => AppColors.textMuted,
    };
    final range = r.approvedStart != null ? r.approvedRangeLabel : r.requestedRangeLabel;
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Icon(r.type.icon, size: 20, color: AppColors.textPrimary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.type.label,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(range, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
          ),
          Text(
            'Estado: ${r.status.label}',
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
