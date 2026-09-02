import 'dart:async';
import 'dart:convert';
import 'package:brl_task4/screens/login.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../design/design.dart';
import '../utils/api_config.dart';

class TaskContainer extends StatefulWidget {
  const TaskContainer({super.key});

  @override
  State<TaskContainer> createState() => TaskContainerState();
}

// progress.dart lee estos contadores; se inicializan en 0 para que esa pantalla
// no reviente si se abre antes de que termine la primera carga.
int? completedTaskNum = 0;
int? incompleteTaskNum = 0;

/// Público (antes `_TaskContainerState`) para que otras pantallas —como el
/// resumen de HomeNav— puedan pedirle, vía GlobalKey, que se desplace a la
/// sección de pendientes/completadas sin duplicar la carga de tareas.
class TaskContainerState extends State<TaskContainer> {
  List<dynamic> compTasks = [];
  List<dynamic> incompTasks = [];
  bool _loading = true;
  // tareas que se están marcando ahora mismo; la clave incluye equipo y área
  // porque dos equipos pueden tener tareas con la misma descripción.
  final Set<String> _updating = {};

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _pendingSectionKey = GlobalKey();
  final GlobalKey _completedSectionKey = GlobalKey();
  // Si nos piden desplazarnos antes de que termine de cargar (p.ej. justo
  // al entrar desde el resumen de Inicio), guardamos el destino y lo
  // resolvemos en cuanto _loadAll termine.
  String? _pendingScrollTarget;

  // Igual que en teamDetail.dart: si el líder reasigna, reprograma o
  // agrega una tarea desde "Gestionar tareas" (u otro dispositivo), esta
  // pantalla lo refleja sola cada pocos segundos, sin depender de que el
  // usuario haga swipe-to-refresh. Se recarga en silencio (sin pasar por
  // el estado de carga inicial) para no interrumpir el scroll ni mostrar
  // el spinner de nuevo.
  Timer? _pollTimer;

  // Antes no incluía el id, así que dos tareas con el mismo texto asignadas
  // a la misma persona compartían la misma clave: al completar una, la otra
  // (idéntica) también se veía "ocupada"/deshabilitada por error. Ahora usa
  // el id cuando está disponible (siempre que el backend ya lo mande) y
  // solo cae de vuelta a la clave por contenido si faltara.
  String _taskKey(Map<String, dynamic> t) =>
      t['id'] != null
          ? 'id:${t['id']}'
          : '${t['teamCode']}|${t['domainName']}|${t['description']}';

  @override
  void initState() {
    super.initState();
    _loadAll();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _silentRefresh());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  /// Igual que incompTaskAPI()/compTaskAPI() pero sin tocar `_loading`, para
  /// que el refresco periódico en segundo plano no vuelva a mostrar el
  /// spinner ni le quite el scroll al usuario. Si alguna de las dos
  /// peticiones falla (p. ej. sin conexión momentánea), esa lista
  /// simplemente conserva sus datos actuales.
  Future<void> _silentRefresh() async {
    if (_loading) return; // ya hay una carga completa en curso
    await Future.wait([incompTaskAPI(), compTaskAPI()]);
  }

  Future<void> _loadAll() async {
    await Future.wait([incompTaskAPI(), compTaskAPI()]);
    if (mounted) setState(() => _loading = false);
    if (_pendingScrollTarget != null) {
      final target = _pendingScrollTarget!;
      _pendingScrollTarget = null;
      _scrollToTarget(target);
    }
  }

  /// Llamado desde fuera (p.ej. al tocar el StatTile "Pendientes"/"Completadas"
  /// en el resumen de Inicio) para saltar a esa sección de esta misma lista.
  void scrollToPending() => _requestScroll('pending');
  void scrollToCompleted() => _requestScroll('completed');

  void _requestScroll(String target) {
    if (_loading) {
      _pendingScrollTarget = target;
      return;
    }
    _scrollToTarget(target);
  }

  void _scrollToTarget(String target) {
    final key = target == 'pending' ? _pendingSectionKey : _completedSectionKey;
    // Se agenda para después del frame en curso: si el widget se acaba de
    // reconstruir (p.ej. tras cambiar de pestaña), su RenderBox todavía no
    // existe en este mismo ciclo.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = key.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
        alignment: 0,
      );
    });
  }

  Future<void> incompTaskAPI() async {
    dynamic storedValue = await secureStorage.readSecureData(key);
    final response = await http.get(
      Uri.parse('$kBaseUrl/team/incompleteTasks'),
      headers: <String, String>{'Authorization': storedValue ?? ''},
    );
    if (!mounted) return;
    if (response.statusCode == 200) {
      setState(() {
        incompTasks = jsonDecode(response.body)['incompleteTasks'] ?? [];
        incompleteTaskNum = incompTasks.length;
      });
    }
  }

  Future<void> compTaskAPI() async {
    dynamic storedValue = await secureStorage.readSecureData(key);
    final response = await http.get(
      Uri.parse('$kBaseUrl/team/completedTasks'),
      headers: <String, String>{'Authorization': storedValue ?? ''},
    );
    if (!mounted) return;
    if (response.statusCode == 200) {
      setState(() {
        compTasks = jsonDecode(response.body)['completedTasks'] ?? [];
        completedTaskNum = compTasks.length;
      });
    }
  }

  Future<void> _completeTask(Map<String, dynamic> task) async {
    final String description = task['description']?.toString() ?? '';
    final String taskKey = _taskKey(task);
    if (_updating.contains(taskKey)) return;

    final bool? confirmed = await showAppConfirmDialog(
      context,
      title: 'Completar tarea',
      message: '¿Marcar "$description" como hecha?',
      confirmLabel: 'Completar',
    );
    if (confirmed != true) return;

    setState(() => _updating.add(taskKey));
    dynamic storedValue = await secureStorage.readSecureData(key);
    try {
      final response = await http.post(
        Uri.parse('$kBaseUrl/team/taskDone'),
        headers: <String, String>{'Authorization': storedValue ?? ''},
        body: {
          'teamCode': task['teamCode']?.toString() ?? '',
          'domainName': task['domainName']?.toString() ?? '',
          'email': task['assignedTo']?.toString() ?? '',
          'task': description,
          // Identifica la fila exacta sin ambigüedad cuando hay dos tareas
          // con el mismo texto asignadas a la misma persona; si por algún
          // motivo no viniera (backend viejo), el backend cae de vuelta al
          // matcheo por contenido.
          if (task['id'] != null) 'taskId': task['id'].toString(),
        },
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        await _loadAll();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tarea completada')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo completar la tarea (${response.statusCode})')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error de red al completar la tarea')),
      );
    } finally {
      if (mounted) setState(() => _updating.remove(taskKey));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      padding: EdgeInsets.zero,
      body: RefreshIndicator(
          onRefresh: _loadAll,
          child: _loading
              ? const LoadingState()
              : ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    Text(
                      'Mis tareas',
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 26, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _summaryChip(
                          Icons.pending_actions,
                          '${incompTasks.length} pendientes',
                          AppColors.warning,
                          onTap: () => scrollToPending(),
                        ),
                        const SizedBox(width: 10),
                        _summaryChip(
                          Icons.check_circle,
                          '${compTasks.length} completadas',
                          AppColors.success,
                          onTap: () => scrollToCompleted(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _sectionTitle('Pendientes', key: _pendingSectionKey),
                    const SizedBox(height: 10),
                    if (incompTasks.isEmpty)
                      const EmptyState(
                        icon: Icons.pending_actions,
                        title: 'No tienes tareas pendientes',
                      )
                    else
                      ...incompTasks.map((t) => _taskCard(Map<String, dynamic>.from(t), done: false)),
                    const SizedBox(height: 24),
                    _sectionTitle('Completadas', key: _completedSectionKey),
                    const SizedBox(height: 10),
                    if (compTasks.isEmpty)
                      const EmptyState(
                        icon: Icons.check_circle_outline,
                        title: 'Todavía no has completado ninguna tarea',
                      )
                    else
                      ...compTasks.map((t) => _taskCard(Map<String, dynamic>.from(t), done: true)),
                  ],
                ),
      ),
    );
  }

  Widget _sectionTitle(String text, {Key? key}) => Text(
        text,
        key: key,
        style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
      );

  Widget _summaryChip(IconData icon, String label, Color color, {VoidCallback? onTap}) {
    return Expanded(
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.surfaceBorder),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _taskCard(Map<String, dynamic> task, {required bool done}) {
    final String description = task['description']?.toString() ?? 'Sin descripción';
    final String teamName = task['teamName']?.toString() ?? '';
    final String domainName = task['domainName']?.toString() ?? '';
    final String deadline = task['deadline']?.toString() ?? '';
    final bool busy = _updating.contains(_taskKey(task));

    final String context_ = [teamName, domainName].where((s) => s.isNotEmpty).join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TaskCard(
        description: description,
        context_: context_,
        deadlineText: deadline,
        done: done,
        busy: busy,
        onComplete: done ? null : () => _completeTask(task),
      ),
    );
  }
}

/// Pantalla independiente que envuelve [TaskContainer] con su propio AppBar
/// (con botón de "atrás"), para poder abrirla desde fuera de HomeNav —por
/// ejemplo al tocar una notificación de tarea asignada, o los botones
/// "Pendientes"/"Completadas" del resumen en Perfil— y que aterrice
/// directamente en la sección pedida sin duplicar la carga de tareas que ya
/// maneja TaskContainer.
class TaskFocusScreen extends StatefulWidget {
  const TaskFocusScreen({super.key, this.showCompleted = false});

  /// Si es `true`, la pantalla aterriza en "Completadas"; por defecto
  /// aterriza en "Pendientes".
  final bool showCompleted;

  @override
  State<TaskFocusScreen> createState() => _TaskFocusScreenState();
}

class _TaskFocusScreenState extends State<TaskFocusScreen> {
  final GlobalKey<TaskContainerState> _taskContainerKey = GlobalKey<TaskContainerState>();

  @override
  void initState() {
    super.initState();
    // Igual que en home_page_home.dart: se pide el scroll tras el primer
    // frame; si TaskContainer todavía está cargando, su propio mecanismo
    // (_pendingScrollTarget) lo aplica en cuanto termine.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.showCompleted) {
        _taskContainerKey.currentState?.scrollToCompleted();
      } else {
        _taskContainerKey.currentState?.scrollToPending();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis tareas')),
      body: TaskContainer(key: _taskContainerKey),
    );
  }
}
