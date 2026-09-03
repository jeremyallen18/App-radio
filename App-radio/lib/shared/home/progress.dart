import 'package:flutter/material.dart';
import 'package:doliv_social/shared/widgets/appbar.dart';
import 'package:doliv_social/shared/widgets/app_menu_drawer.dart';
import 'package:doliv_social/shared/home/tasks.dart';
import 'package:doliv_social/shared/home/director_performance_view.dart';
import 'package:doliv_social/shared/home/personal_progress_view.dart';
import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/core/session.dart';
import 'package:doliv_social/core/storeToken.dart';
import 'package:doliv_social/models/models.dart';
import 'package:doliv_social/services/team_service.dart';

class ProgressChart extends StatefulWidget {
  const ProgressChart({Key? key}) : super(key: key);

  @override
  State<ProgressChart> createState() => _ProgressChartState();
}

class _ProgressChartState extends State<ProgressChart> {
  late Future<void> _dataFuture;

  // El director ve el desempeño de TODOS los departamentos (cuántas tareas
  // ha completado cada área) en vez de su progreso personal, que para él
  // casi siempre está vacío. Los demás roles siguen viendo "Tu progreso".
  bool _isDirector = false;
  DeptTasksByDepartment? _deptPerformance;

  static const String _tokenKey = 'accessToken';
  static final SecureStorage _secureStorage = SecureStorage();

  @override
  void initState() {
    super.initState();
    _dataFuture = _load();
  }

  Future<void> _load() async {
    // Se pide el rol fresco a `/user/me` (y solo se cae al caché si falla),
    // igual que RoleDashboardRouter. Con `getCachedRole()` el director veía
    // la vista de empleado ("Aún no hay tareas asignadas") cuando el caché
    // estaba vacío o desactualizado.
    final token = await _secureStorage.readSecureData(_tokenKey);
    final role = await Session.getFreshRole(token as String?);
    _isDirector = role == AppRole.director;
    if (_isDirector) {
      _deptPerformance = await DeptTaskApi.summaryByDepartment();
      return;
    }
    await refreshTaskCounts();
  }

  Future<void> _reload() {
    final future = _load();
    setState(() => _dataFuture = future);
    return future;
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: MyAppBar(),
      drawer: const AppMenuDrawer(),
      scrollable: true,
      body: FutureBuilder<void>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xxxl),
              child: LoadingState(
                message: _isDirector
                    ? 'Cargando el desempeño de los departamentos...'
                    : 'Cargando tu progreso...',
              ),
            );
          }

          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xxxl),
              child: ErrorState(onRetry: _reload),
            );
          }

          if (_isDirector) {
            return DirectorPerformanceView(data: _deptPerformance);
          }
          return PersonalProgressView(
            completed: completedTaskNum ?? 0,
            incomplete: incompleteTaskNum ?? 0,
          );
        },
      ),
    );
  }
}
