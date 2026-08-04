import 'dart:convert';

import 'package:brl_task4/models/appbar.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:brl_task4/home_page/teams.dart';
import 'package:brl_task4/home_page/tasks.dart';
import 'package:brl_task4/screens/login.dart';
import '../design/design.dart';
import '../utils/Routes.dart';
import '../utils/api_config.dart';

class HomeNav extends StatefulWidget {
  const HomeNav({super.key});

  @override
  _HomeNavState createState() => _HomeNavState();
}

class _HomeNavState extends State<HomeNav> {
  int _selectedIndex = 0;
  final List<Widget> _pages = const [
    TaskContainer(),
    TeamPage(),
  ];

  int? _pendingCount;
  int? _completedCount;
  int? _teamsCount;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  // Reutiliza los mismos endpoints que ya consumen tasks.dart y dashboard.dart
  // (GET, solo lectura) — únicamente para mostrar el resumen del dashboard.
  Future<void> _loadSummary() async {
    final token = await secureStorage.readSecureData(key);
    final headers = <String, String>{'Authorization': token ?? ''};

    Future<int?> count(String path, String field) async {
      try {
        final response = await http.get(Uri.parse('$kBaseUrl/$path'), headers: headers);
        if (response.statusCode != 200) return null;
        final decoded = jsonDecode(response.body);
        final List<dynamic> list = decoded[field] ?? [];
        return list.length;
      } catch (_) {
        return null;
      }
    }

    final results = await Future.wait([
      count('team/incompleteTasks', 'incompleteTasks'),
      count('team/completedTasks', 'completedTasks'),
      count('team/showTeams', 'teams'),
    ]);

    if (!mounted) return;
    setState(() {
      _pendingCount = results[0];
      _completedCount = results[1];
      _teamsCount = results[2];
    });
  }

  void _onNavItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const MyAppBar(),
      backgroundColor: AppColors.bgBase,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(
                  title: 'Resumen',
                  action: IconButton(
                    tooltip: 'Actualizar',
                    onPressed: _loadSummary,
                    icon: const Icon(Icons.refresh, color: AppColors.textMuted, size: 20),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: StatTile(
                        icon: Icons.pending_actions,
                        value: _pendingCount?.toString() ?? '—',
                        label: 'Pendientes',
                        accentColor: AppColors.warning,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: StatTile(
                        icon: Icons.check_circle_outline,
                        value: _completedCount?.toString() ?? '—',
                        label: 'Completadas',
                        accentColor: AppColors.success,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: StatTile(
                        icon: Icons.groups_outlined,
                        value: _teamsCount?.toString() ?? '—',
                        label: 'Equipos',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),

                const SectionHeader(title: 'Acciones rápidas'),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    QuickActionChip(
                      icon: Icons.add_circle_outline,
                      label: 'Crear equipo',
                      onTap: () => Navigator.pushNamed(context, MyRoutes.CreateTeamScreen),
                    ),
                    QuickActionChip(
                      icon: Icons.group_add_outlined,
                      label: 'Unirse a un equipo',
                      onTap: () => Navigator.pushNamed(context, MyRoutes.jointeamRoutes),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),

                SectionHeader(
                  title: _selectedIndex == 0 ? 'Mis tareas' : 'Mis equipos',
                  action: SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 0, label: Text('Tareas'), icon: Icon(Icons.checklist, size: 16)),
                      ButtonSegment(value: 1, label: Text('Equipos'), icon: Icon(Icons.groups, size: 16)),
                    ],
                    selected: {_selectedIndex},
                    showSelectedIcon: false,
                    onSelectionChanged: (selection) => _onNavItemTapped(selection.first),
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // TaskContainer/TeamPage manejan su propia carga, refresco y scroll
          // internamente — sin tocar su lógica, solo se les da el espacio
          // restante de la pantalla.
          Expanded(child: _pages[_selectedIndex]),
        ],
      ),
    );
  }
}
