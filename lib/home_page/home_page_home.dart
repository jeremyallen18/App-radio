import 'dart:async';
import 'dart:convert';

import 'package:brl_task4/models/appbar.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:brl_task4/home_page/teams.dart';
import 'package:brl_task4/home_page/tasks.dart';
import 'package:brl_task4/screens/login.dart';
import '../design/design.dart';
import '../screens/messagesDashboard.dart';
import '../utils/Routes.dart';
import '../utils/api_config.dart';

class HomeNav extends StatefulWidget {
  const HomeNav({super.key});

  @override
  _HomeNavState createState() => _HomeNavState();
}

class _HomeNavState extends State<HomeNav> {
  int _selectedIndex = 0;

  // GlobalKey para poder pedirle a TaskContainer (pestaña "Tareas") que se
  // desplace a la sección de pendientes/completadas cuando se toca el
  // StatTile correspondiente en "Resumen", sin duplicar su lógica de carga.
  final GlobalKey<TaskContainerState> _taskContainerKey = GlobalKey<TaskContainerState>();
  late final List<Widget> _pages = [
    TaskContainer(key: _taskContainerKey),
    const TeamPage(),
  ];

  int? _pendingCount;
  int? _completedCount;
  int? _teamsCount;
  int _unreadMessagesCount = 0;
  Timer? _unreadPollTimer;

  // Controla el colapso de "Resumen" y "Acciones rápidas" al desplazar la
  // lista (Mis tareas / Mis equipos). 0 = totalmente visible, 1 = oculto.
  // _collapseDistance es la cantidad de píxeles de scroll necesarios para
  // ocultar por completo esa sección; no necesita coincidir exactamente con
  // su alto real, solo dar una transición suave.
  static const double _collapseDistance = 220.0;
  double _headerScrollOffset = 0;
  double get _collapseFraction => (_headerScrollOffset / _collapseDistance).clamp(0.0, 1.0);

  bool _handleContentScroll(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification || notification is OverscrollNotification) {
      final double delta = notification is ScrollUpdateNotification
          ? (notification.scrollDelta ?? 0)
          : (notification as OverscrollNotification).overscroll;
      if (delta != 0) {
        setState(() {
          _headerScrollOffset = (_headerScrollOffset + delta).clamp(0.0, _collapseDistance);
        });
      }
    }
    // Devolver false para dejar que la notificación siga burbujeando
    // (p.ej. hacia un ancestro Scrollable, si lo hubiera).
    return false;
  }

  @override
  void initState() {
    super.initState();
    _loadSummary();
    _loadUnreadMessagesCount();
    // Mismo criterio que el badge de notificaciones (lib/models/appbar.dart):
    // se refresca solo cada cierto tiempo para que el número se sienta al
    // día aunque la persona no vuelva a entrar a "Mensajes".
    _unreadPollTimer =
        Timer.periodic(const Duration(seconds: 15), (_) => _loadUnreadMessagesCount());
  }

  @override
  void dispose() {
    _unreadPollTimer?.cancel();
    super.dispose();
  }

  // Suma el 'unreadCount' de cada chat (de equipo y directos) que ya trae
  // GET /chat/list (hive-backend/index.php, listChats()), para mostrar el
  // total en la burbuja del botón "Mensajes".
  Future<void> _loadUnreadMessagesCount() async {
    try {
      final token = await secureStorage.readSecureData(key);
      final response = await http.get(
        Uri.parse('$kBaseUrl/chat/list'),
        headers: <String, String>{'Authorization': token ?? ''},
      );
      if (!mounted || response.statusCode != 200) return;
      final decoded = jsonDecode(response.body);
      final List<dynamic> chats = decoded['chats'] ?? [];
      final int total = chats.fold<int>(0, (sum, c) {
        final raw = c['unreadCount'];
        final count = raw is num ? raw.toInt() : int.tryParse(raw?.toString() ?? '') ?? 0;
        return sum + count;
      });
      setState(() => _unreadMessagesCount = total);
    } catch (_) {
      // Silencioso: no interrumpe el resto del inicio si falla.
    }
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

  // Al tocar "Pendientes" o "Completadas" en Resumen: cambia a la pestaña
  // "Tareas" (si no estaba ya en ella) y le pide a TaskContainer que se
  // desplace a esa sección. Si TaskContainer ya estaba visible, el salto es
  // inmediato; si había que cambiar de pestaña, se reconstruye y luego se
  // desplaza (TaskContainerState._pendingScrollTarget cubre esa espera).
  void _goToTasksSection({required bool pending}) {
    setState(() => _selectedIndex = 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = _taskContainerKey.currentState;
      if (state == null) return;
      if (pending) {
        state.scrollToPending();
      } else {
        state.scrollToCompleted();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const MyAppBar(),
      backgroundColor: AppColors.bgBase,
      body: Column(
        children: [
          // "Resumen" y "Acciones rápidas": se van ocultando (recortando
          // desde abajo con Align.heightFactor) a medida que el usuario
          // desliza la lista de abajo, y reaparecen al desplazarse de
          // vuelta hacia arriba.
          ClipRect(
            child: Align(
              alignment: Alignment.topCenter,
              heightFactor: 1 - _collapseFraction,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeader(
                      title: 'Resumen',
                      action: IconButton(
                        tooltip: 'Actualizar',
                        onPressed: _loadSummary,
                        icon: Icon(Icons.refresh, color: AppColors.textMuted, size: 20),
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
                            onTap: () => _goToTasksSection(pending: true),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: StatTile(
                            icon: Icons.check_circle_outline,
                            value: _completedCount?.toString() ?? '—',
                            label: 'Completadas',
                            accentColor: AppColors.success,
                            onTap: () => _goToTasksSection(pending: false),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: StatTile(
                            icon: Icons.groups_outlined,
                            value: _teamsCount?.toString() ?? '—',
                            label: 'Equipos',
                            onTap: () => _onNavItemTapped(1),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    // Botón ancho de lado a lado, debajo de "Pendientes /
                    // Completadas / Equipos": abre el dashboard de chats
                    // (equipo y directos), tipo WhatsApp.
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: AppButton(
                            label: '✉️ Mensajes',
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const MessagesDashboardScreen()),
                              ).then((_) => _loadUnreadMessagesCount());
                            },
                          ),
                        ),
                        // Burbuja con el total de mensajes sin leer (equipo +
                        // directos), tipo icono de app con notificación.
                        Positioned(
                          top: -8,
                          right: 8,
                          child: UnreadCountBadge(count: _unreadMessagesCount),
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
                  ],
                ),
              ),
            ),
          ),
          // Selector de pestañas: se mantiene siempre visible, incluso
          // cuando "Resumen" y "Acciones rápidas" están ocultas.
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
            child: SectionHeader(
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
          ),
          // TaskContainer/TeamPage manejan su propia carga, refresco y scroll
          // internamente — sin tocar su lógica. Solo escuchamos las
          // notificaciones de scroll que "burbujean" desde su ListView
          // interno para saber cuánto colapsar el encabezado de arriba.
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: _handleContentScroll,
              child: _pages[_selectedIndex],
            ),
          ),
        ],
      ),
    );
  }
}
