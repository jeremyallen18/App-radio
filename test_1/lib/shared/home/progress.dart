import 'package:flutter/material.dart';
import 'package:doliv_social/shared/widgets/appbar.dart';
import 'package:doliv_social/shared/widgets/app_menu_drawer.dart';
import 'package:doliv_social/shared/home/director_performance_view.dart';
import 'package:doliv_social/shared/home/personal_progress_view.dart';
import 'package:doliv_social/shared/home/progress/progress_stats.dart';
import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/core/session.dart';
import 'package:doliv_social/core/storeToken.dart';
import 'package:doliv_social/models/models.dart';
import 'package:doliv_social/services/team_service.dart';

class ProgressChart extends StatefulWidget {
  /// `true` cuando es la pestaña "Progreso" del `BottomNavBar`: el shell ya
  /// pinta la `MyAppBar` y el menú fijos, así que esta pantalla no los repite.
  /// Como ruta suelta (menú → "Mi progreso") sí los trae.
  const ProgressChart({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<ProgressChart> createState() => _ProgressChartState();
}

class _ProgressChartState extends State<ProgressChart> {
  late Future<void> _dataFuture;

  // El director ve el desempeño de TODOS los departamentos en vez de su
  // progreso personal, que para él casi siempre está vacío.
  bool _isDirector = false;
  DeptTasksByDepartment? _deptPerformance;
  ProgressStats? _companyStats;
  ProgressStats? _myStats;

  static const String _tokenKey = 'accessToken';
  static final SecureStorage _secureStorage = SecureStorage();

  @override
  void initState() {
    super.initState();
    _dataFuture = _load();
  }

  Future<void> _load() async {
    // Se pide el rol fresco a `/user/me` (y solo se cae al caché si falla),
    // igual que RoleDashboardRouter.
    final token = await _secureStorage.readSecureData(_tokenKey);
    final role = await Session.getFreshRole(token as String?);
    _isDirector = role == AppRole.director;
    if (_isDirector) {
      // El desglose por departamento es lo imprescindible; el listado
      // completo (para el ritmo semanal) es un extra que puede fallar solo.
      final results = await Future.wait([
        DeptTaskApi.summaryByDepartment(),
        DeptTaskApi.list().then<ProgressStats?>(ProgressStats.fromTasks).catchError((_) => null),
      ]);
      _deptPerformance = results[0] as DeptTasksByDepartment;
      _companyStats = results[1] as ProgressStats?;
      return;
    }
    _myStats = ProgressStats.fromTasks(await DeptTaskApi.list(mine: true));
  }

  Future<void> _reload() {
    final future = _load();
    setState(() => _dataFuture = future);
    return future;
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: widget.embedded ? null : const MyAppBar(),
      drawer: widget.embedded ? null : const AppMenuDrawer(),
      showBackButton: !widget.embedded,
      padding: EdgeInsets.zero,
      body: FutureBuilder<void>(
        future: _dataFuture,
        builder: (context, snapshot) {
          final Widget child;
          if (snapshot.connectionState == ConnectionState.waiting) {
            child = Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xxxl),
              child: LoadingState(
                message: _isDirector
                    ? 'Cargando el desempeño de los departamentos...'
                    : 'Cargando tu progreso...',
              ),
            );
          } else if (snapshot.hasError) {
            child = Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xxxl),
              child: ErrorState(onRetry: _reload),
            );
          } else if (_isDirector) {
            child = DirectorPerformanceView(
              data: _deptPerformance,
              companyStats: _companyStats,
            );
          } else {
            child = PersonalProgressView(
              stats: _myStats ?? ProgressStats.fromTasks(const []),
            );
          }
          return RefreshIndicator(
            onRefresh: _reload,
            color: AppColors.accent,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: child,
            ),
          );
        },
      ),
    );
  }
}
