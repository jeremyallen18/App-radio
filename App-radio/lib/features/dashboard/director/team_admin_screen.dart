import 'package:flutter/material.dart';

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/features/dashboard/director/create_company_card.dart';
import 'package:doliv_social/models/models.dart';
import 'package:doliv_social/services/company_service.dart';
import 'package:doliv_social/services/team_service.dart';
import 'package:doliv_social/shared/teams/team_detail_screen.dart';

/// Diálogo de alta de equipo. Es un `StatefulWidget` propio para que sus
/// `TextEditingController` los libere `dispose()` — que el framework solo
/// invoca cuando la ruta del diálogo ya salió del árbol. Liberarlos justo
/// después de `await showDialog(...)`, con la animación de cierre todavía en
/// curso, dejaba a los `TextField` usando un controller ya destruido y
/// reventaba con `'_dependents.isEmpty': is not true`.
///
/// Devuelve `({String name, String description})` al confirmar, o `null` al
/// cancelar / descartar.
@visibleForTesting
class CreateTeamDialog extends StatefulWidget {
  const CreateTeamDialog({super.key});

  @override
  State<CreateTeamDialog> createState() => _CreateTeamDialogState();
}

class _CreateTeamDialogState extends State<CreateTeamDialog> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.pop(
      context,
      (name: _nameCtrl.text.trim(), description: _descCtrl.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Crear equipo'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppTextField(controller: _nameCtrl, hintText: 'Nombre del equipo'),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _descCtrl,
            hintText: 'Descripción (opcional)',
            maxLines: 2,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar', style: TextStyle(color: AppColors.textMuted)),
        ),
        TextButton(
          onPressed: _submit,
          child: const Text('Crear'),
        ),
      ],
    );
  }
}

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

  /// No se puede crear un área sin empresa. Si todavía no existe, esta
  /// pantalla ofrece crearla en vez de dejar que "Crear equipo" falle con un
  /// error sin salida ("Crea la empresa antes de agregar departamentos").
  bool _companyMissing = false;

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
      final company = await CompanyApi.fetch();
      if (!mounted) return;
      if (company == null) {
        setState(() {
          _companyMissing = true;
          _loading = false;
        });
        return;
      }
      final d = await TeamApi.listDepartments();
      if (!mounted) return;
      setState(() {
        _companyMissing = false;
        _departments = d;
        _loading = false;
      });
    } on CompanyException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
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
    final result = await showDialog<({String name, String description})>(
      context: context,
      builder: (dialogContext) => const CreateTeamDialog(),
    );
    if (result == null) return;
    final name = result.name;
    final desc = result.description;
    if (name.isEmpty) return;
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
      // Sin empresa no hay "Crear equipo": la pantalla ofrece crear la empresa.
      floatingActionButton: (_loading || _error != null || _companyMissing)
          ? null
          : FloatingActionButton.extended(
              onPressed: _createTeam,
              icon: const Icon(Icons.add),
              label: const Text('Crear equipo'),
            ),
      body: Builder(
        builder: (context) {
          if (_loading) return const LoadingState();
          if (_error != null) return ErrorState(message: _error!, onRetry: _load);
          if (_companyMissing) {
            return CreateCompanyCard(onCreated: (_) => _load());
          }
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
