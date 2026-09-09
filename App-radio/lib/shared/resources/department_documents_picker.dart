import 'package:flutter/material.dart';

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/models/models.dart';
import 'package:doliv_social/services/team_service.dart';
import 'package:doliv_social/shared/resources/department_documents_screen.dart';

/// Paso previo solo para el director: elige el departamento cuyos documentos
/// quiere gestionar. Manager y empleado entran directo al de su propio
/// departamento, así que no ven esta pantalla.
class DepartmentDocumentsPicker extends StatefulWidget {
  const DepartmentDocumentsPicker({super.key});

  @override
  State<DepartmentDocumentsPicker> createState() =>
      _DepartmentDocumentsPickerState();
}

class _DepartmentDocumentsPickerState extends State<DepartmentDocumentsPicker> {
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
      final list = await TeamApi.listDepartments();
      if (!mounted) return;
      setState(() {
        _departments = list;
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

  void _open(DepartmentInfo d) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => DepartmentDocumentsScreen(
        departmentId: d.id,
        departmentName: d.name,
        canManage: true,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(title: const Text('Documentos por departamento')),
      scrollable: false,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const LoadingState();
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);
    if (_departments.isEmpty) {
      return const EmptyState(
        icon: Icons.apartment_outlined,
        title: 'No hay departamentos',
        message: 'Crea un departamento antes de compartir documentos.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: _departments.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, i) {
        final d = _departments[i];
        return AppCard(
          onTap: () => _open(d),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.folder_shared_outlined,
                    color: AppColors.accent, size: 20),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  d.name,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: AppColors.textMuted),
            ],
          ),
        );
      },
    );
  }
}
