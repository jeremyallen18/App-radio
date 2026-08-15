import 'dart:convert';
import 'package:doliv_social/screens/login.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../design/design.dart';
import '../utils/api_config.dart';

class TaskContainer extends StatefulWidget {
  const TaskContainer({super.key});

  @override
  State<TaskContainer> createState() => _TaskContainerState();
}

// progress.dart lee estos contadores; se inicializan en 0 para que esa pantalla
// no reviente si se abre antes de que termine la primera carga.
int? completedTaskNum = 0;
int? incompleteTaskNum = 0;

/// Pide los conteos de tareas propias directamente al backend y actualiza
/// [completedTaskNum]/[incompleteTaskNum]. `progress.dart` la llama al
/// abrirse: antes esos contadores solo se llenaban si el usuario ya había
/// visitado "Mis tareas" (`TaskContainer`), así que el gráfico de progreso
/// podía mostrar "sin tareas" con datos desactualizados o en cero aunque el
/// usuario sí tuviera tareas asignadas.
Future<void> refreshTaskCounts() async {
  final dynamic storedValue = await secureStorage.readSecureData(key);
  final headers = <String, String>{'Authorization': storedValue ?? ''};

  final responses = await Future.wait([
    http.get(Uri.parse('$kBaseUrl/team/incompleteTasks'), headers: headers),
    http.get(Uri.parse('$kBaseUrl/team/completedTasks'), headers: headers),
  ]);

  final incompleteResponse = responses[0];
  final completedResponse = responses[1];

  if (incompleteResponse.statusCode == 200) {
    final List<dynamic> tasks =
        jsonDecode(incompleteResponse.body)['incompleteTasks'] ?? [];
    incompleteTaskNum = tasks.length;
  }
  if (completedResponse.statusCode == 200) {
    final List<dynamic> tasks =
        jsonDecode(completedResponse.body)['completedTasks'] ?? [];
    completedTaskNum = tasks.length;
  }
}

class _TaskContainerState extends State<TaskContainer> {
  List<dynamic> compTasks = [];
  List<dynamic> incompTasks = [];
  bool _loading = true;
  // tareas que se están marcando ahora mismo; la clave incluye equipo y área
  // porque dos equipos pueden tener tareas con la misma descripción.
  final Set<String> _updating = {};

  String _taskKey(Map<String, dynamic> t) =>
      '${t['teamCode']}|${t['domainName']}|${t['description']}';

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([incompTaskAPI(), compTaskAPI()]);
    if (mounted) setState(() => _loading = false);
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
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    const Text(
                      'Mis tareas',
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 26, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _summaryChip(Icons.pending_actions, '${incompTasks.length} pendientes', AppColors.warning),
                        const SizedBox(width: 10),
                        _summaryChip(Icons.check_circle, '${compTasks.length} completadas', AppColors.success),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _sectionTitle('Pendientes'),
                    const SizedBox(height: 10),
                    if (incompTasks.isEmpty)
                      const EmptyState(
                        icon: Icons.pending_actions,
                        title: 'No tienes tareas pendientes',
                      )
                    else
                      ResponsiveCardGrid(
                        children: [
                          for (final t in incompTasks)
                            _taskCard(Map<String, dynamic>.from(t), done: false),
                        ],
                      ),
                    const SizedBox(height: 24),
                    _sectionTitle('Completadas'),
                    const SizedBox(height: 10),
                    if (compTasks.isEmpty)
                      const EmptyState(
                        icon: Icons.check_circle_outline,
                        title: 'Todavía no has completado ninguna tarea',
                      )
                    else
                      ResponsiveCardGrid(
                        children: [
                          for (final t in compTasks)
                            _taskCard(Map<String, dynamic>.from(t), done: true),
                        ],
                      ),
                  ],
                ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(
        text,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
      );

  Widget _summaryChip(IconData icon, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
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
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
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
