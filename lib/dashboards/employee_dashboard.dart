import 'package:flutter/material.dart';

import '../design/design.dart';
import '../home_page/tasks.dart';
import '../models/models.dart';
import '../screens/login.dart'; // globals `secureStorage` / `key` (accessToken)
import '../utils/Routes.dart';
import '../utils/session.dart';
import 'dashboard_widgets.dart';

/// Dashboard del Employee: reutiliza `TaskContainer` (mis tareas) de
/// `lib/home_page/*`, tal como sugiere el área.
///
/// El detalle de "mi progreso" (gráfica) sigue viviendo en la pestaña
/// "Progreso" de `BottomNavBar` (no se duplica aquí). Calendario,
/// anuncios, chat del departamento y recursos compartidos dependen de
/// módulos que otras áreas todavía están construyendo (ver
/// `actualizaciones/README.md`) — mientras tanto se muestran como
/// "Próximamente". "Solicitudes de permiso" ya funciona hoy pero requiere
/// elegir un equipo primero (`ApplyLeave` se abre desde `teamDetail.dart`),
/// así que aquí solo se enlaza al listado de equipos.
class EmployeeDashboard extends StatefulWidget {
  const EmployeeDashboard({super.key});

  @override
  State<EmployeeDashboard> createState() => _EmployeeDashboardState();
}

class _EmployeeDashboardState extends State<EmployeeDashboard> {
  UserProfile? _profile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final token = await secureStorage.readSecureData(key);
    final profile = await Session.fetchCurrentUser(token ?? '');
    if (!mounted) return;
    setState(() => _profile = profile);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxxl),
      children: [
        DashboardHeader(
          title: _profile != null ? 'Hola, ${_profile!.name}' : 'Panel del Empleado',
          roleLabel: _profile?.role.label,
        ),

        const SectionHeader(title: 'Acciones rápidas'),
        const QuickTeamActions(),
        const SizedBox(height: AppSpacing.xl),

        // TaskContainer ya trae su propio título "Mis tareas" y resumen
        // pendientes/completadas — se embebe tal cual, igual que hoy en
        // HomeNav, en un alto fijo con scroll propio.
        const SizedBox(height: 480, child: TaskContainer()),
        const SizedBox(height: AppSpacing.xl),

        const SectionHeader(title: 'Mi progreso'),
        AppCard(
          child: Row(
            children: [
              const Icon(Icons.pie_chart_outline, color: AppColors.accent, size: 20),
              const SizedBox(width: AppSpacing.md),
              const Expanded(
                child: Text(
                  'Consulta el detalle de tu progreso en la pestaña "Progreso".',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        const ComingSoonSection(
          title: 'Mi calendario',
          message: 'Tu calendario estará disponible próximamente.',
        ),
        const ComingSoonSection(
          title: 'Mis anuncios',
          message: 'Tus anuncios estarán disponibles próximamente.',
        ),
        const ComingSoonSection(
          title: 'Chat del departamento',
          message: 'El chat de tu departamento estará disponible próximamente.',
        ),
        const ComingSoonSection(
          title: 'Recursos compartidos',
          message: 'Los recursos compartidos estarán disponibles próximamente.',
        ),

        const SectionHeader(title: 'Solicitudes de permiso'),
        AppCard(
          onTap: () => Navigator.pushNamed(context, MyRoutes.dashbMemRoutes),
          child: const Row(
            children: [
              Icon(Icons.event_busy_outlined, color: AppColors.accent, size: 20),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'Solicita un permiso desde el equipo correspondiente.',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
                ),
              ),
              Icon(Icons.chevron_right, color: AppColors.textMuted),
            ],
          ),
        ),
      ],
    );
  }
}
