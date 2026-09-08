import 'package:flutter/material.dart';

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/models/models.dart';
import 'package:doliv_social/services/team_service.dart';
import 'package:doliv_social/shared/teams/team_detail_screen.dart';

/// "Equipos" (director): lista de departamentos, crear equipo nuevo y entrar
/// a cada uno para asignar manager, miembros y tareas.
class TeamAdminScreen extends StatefulWidget {
  const TeamAdminScreen({super.key});

  @override
  State<TeamAdminScreen> createState() => _TeamAdminScreenState();
}

class _TeamAdminScreenState extends State<TeamAdminScreen> {
  List<DepartmentInfo> _departments = const [];
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
      final d = await TeamApi.listDepartments();
      if (!mounted) return;
      setState(() {
        _departments = d;
        _loading = false;
      });
    } on TeamException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _createTeam() async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Crear equipo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(controller: nameCtrl, hintText: 'Nombre del equipo'),
            const SizedBox(height: AppSpacing.md),
            AppTextField(controller: descCtrl, hintText: 'Descripción (opcional)', maxLines: 2),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Crear'),
          ),
        ],
      ),
    );
    final name = nameCtrl.text.trim();
    final desc = descCtrl.text.trim();
    nameCtrl.dispose();
    descCtrl.dispose();
    if (created != true || name.isEmpty) return;
    try {
      await TeamApi.createDepartment(name: name, description: desc);
      _load();
    } on TeamException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(leading: const BackButton(), title: const Text('Equipos')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createTeam,
        icon: const Icon(Icons.add),
        label: const Text('Crear equipo'),
      ),
      body: Builder(
        builder: (context) {
          if (_loading) return const LoadingState();
          if (_error != null) return ErrorState(message: _error!, onRetry: _load);
          if (_departments.isEmpty) {
            return const EmptyState(
              icon: Icons.groups_2_outlined,
              title: 'Todavía no hay equipos',
              message: 'Toca "Crear equipo" para empezar.',
            );
          }
          return RefreshIndicator(
            color: AppColors.accent,
            onRefresh: _load,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 96),
              itemCount: _departments.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (_, i) {
                final d = _departments[i];
                final hasManager = (d.managerEmail ?? '').isNotEmpty;
                return AppCard(
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => TeamDetailScreen(department: d)),
                    );
                    _load();
                  },
                  child: Row(
                    children: [
                      IdentityAvatar(id: d.name),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(d.name,
                                style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15)),
                            const SizedBox(height: 2),
                            Text(
                              hasManager ? 'Manager: ${d.managerEmail}' : 'Sin manager asignado',
                              style: TextStyle(
                                color: hasManager ? AppColors.textMuted : AppColors.warning,
                                fontSize: 12,
                                fontWeight: hasManager ? FontWeight.w400 : FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      AppBadge(label: '${d.employeeCount} empleados'),
                      const SizedBox(width: AppSpacing.sm),
                      const Icon(Icons.chevron_right, color: AppColors.textMuted),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
