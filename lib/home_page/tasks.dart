import 'dart:convert';
import 'package:brl_task4/screens/login.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../utils/api_config.dart';
import '../utils/colors.dart';

class TaskContainer extends StatefulWidget {
  const TaskContainer({super.key});

  @override
  State<TaskContainer> createState() => _TaskContainerState();
}

// progress.dart lee estos contadores; se inicializan en 0 para que esa pantalla
// no reviente si se abre antes de que termine la primera carga.
int? completedTaskNum = 0;
int? incompleteTaskNum = 0;

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

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.darkField,
        title: const Text('Completar tarea', style: TextStyle(color: Colors.white)),
        content: Text(
          '¿Marcar "$description" como hecha?',
          style: const TextStyle(color: AppColors.darkMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.darkMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Completar', style: TextStyle(color: AppColors.accentIndigoLight)),
          ),
        ],
      ),
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
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadAll,
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.accentIndigoLight))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    const Text(
                      'Mis tareas',
                      style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _summaryChip(Icons.pending_actions, '${incompTasks.length} pendientes', Colors.orangeAccent),
                        const SizedBox(width: 10),
                        _summaryChip(Icons.check_circle, '${compTasks.length} completadas', Colors.greenAccent),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _sectionTitle('Pendientes'),
                    const SizedBox(height: 10),
                    if (incompTasks.isEmpty)
                      _emptyState('No tienes tareas pendientes')
                    else
                      ...incompTasks.map((t) => _taskCard(Map<String, dynamic>.from(t), done: false)),
                    const SizedBox(height: 24),
                    _sectionTitle('Completadas'),
                    const SizedBox(height: 10),
                    if (compTasks.isEmpty)
                      _emptyState('Todavía no has completado ninguna tarea')
                    else
                      ...compTasks.map((t) => _taskCard(Map<String, dynamic>.from(t), done: true)),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
      );

  Widget _summaryChip(IconData icon, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.darkField,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.darkFieldBorder),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.darkField.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.darkFieldBorder),
      ),
      child: Text(message, style: const TextStyle(color: AppColors.darkMuted, fontSize: 13)),
    );
  }

  Widget _taskCard(Map<String, dynamic> task, {required bool done}) {
    final String description = task['description']?.toString() ?? 'Sin descripción';
    final String teamName = task['teamName']?.toString() ?? '';
    final String domainName = task['domainName']?.toString() ?? '';
    final String deadline = task['deadline']?.toString() ?? '';
    final bool busy = _updating.contains(_taskKey(task));

    final String context_ = [teamName, domainName].where((s) => s.isNotEmpty).join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.darkField,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: done ? AppColors.darkFieldBorder : AppColors.accentIndigo.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: TextStyle(
                    color: done ? AppColors.darkMuted : Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    decoration: done ? TextDecoration.lineThrough : TextDecoration.none,
                  ),
                ),
                if (context_.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(context_, style: const TextStyle(color: AppColors.darkMuted, fontSize: 12)),
                ],
                if (deadline.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.event, size: 14, color: AppColors.darkMuted),
                      const SizedBox(width: 5),
                      Text(deadline, style: const TextStyle(color: AppColors.darkMuted, fontSize: 12)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (done)
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(Icons.check_circle, color: Colors.greenAccent, size: 26),
            )
          else if (busy)
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentIndigoLight),
            )
          else
            IconButton(
              tooltip: 'Completar tarea',
              onPressed: () => _completeTask(task),
              icon: const Icon(Icons.radio_button_unchecked, color: AppColors.accentIndigoLight, size: 26),
            ),
        ],
      ),
    );
  }
}
