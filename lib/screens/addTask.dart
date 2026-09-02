import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../design/design.dart';
import '../utils/Routes.dart';
import '../utils/api_config.dart';
import 'login.dart';

class addTask extends StatefulWidget {
  addTask({super.key, required this.teamcode, this.domains});
  dynamic teamcode;
  final List<dynamic>? domains;

  @override
  State<addTask> createState() => _addTaskState();
}

class _addTaskState extends State<addTask> {
  String? selectedDomain;
  // Antes era un único miembro (String?); ahora se puede marcar a varios a
  // la vez para que la misma tarea quede asignada a todos ellos.
  final Set<String> selectedMembers = {};
  bool _submitting = false;
  // Cuántas tareas se agregaron en esta visita a la pantalla, para que el
  // admin pueda seguir sumando tareas sin perder la cuenta ni tener que
  // volver a entrar a "Agregar tarea" cada vez.
  int _addedCount = 0;

  List<String> get _domainNames =>
      (widget.domains ?? []).map((d) => d['name'].toString()).toSet().toList();

  List<String> get _membersForSelectedDomain {
    if (selectedDomain == null) return [];
    final domain = (widget.domains ?? []).firstWhere(
      (d) => d['name'] == selectedDomain,
      orElse: () => null,
    );
    if (domain == null) return [];
    return ((domain['members'] as List?) ?? []).map((m) => m.toString()).toSet().toList();
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null) return;
    final dd = picked.day.toString().padLeft(2, '0');
    final mm = picked.month.toString().padLeft(2, '0');
    // Mismo formato dd-MM-yyyy que ya esperaba el campo de texto libre
    // original, para no romper el parseo de fecha en el resto de la app.
    setState(() => DeadlineController.text = '$dd-$mm-${picked.year}');
  }

  void _toggleMember(String member) {
    setState(() {
      if (selectedMembers.contains(member)) {
        selectedMembers.remove(member);
      } else {
        selectedMembers.add(member);
      }
    });
  }

  void _toggleSelectAllMembers() {
    final all = _membersForSelectedDomain;
    setState(() {
      if (selectedMembers.length == all.length && all.isNotEmpty) {
        selectedMembers.clear();
      } else {
        selectedMembers
          ..clear()
          ..addAll(all);
      }
    });
  }

  // El backend sigue recibiendo un solo email por llamada (una fila en
  // `tasks` por persona asignada); aquí simplemente se dispara una llamada
  // por cada miembro marcado, todas con la misma descripción/fecha límite,
  // para que la tarea quede "compartida" entre todos ellos.
  Future<bool> _postTaskFor(String teamcode, String email) async {
    dynamic storedValue = await secureStorage.readSecureData(key);
    final String apiUrl = '$kBaseUrl/team/task/$teamcode';
    final response = await http.post(
      Uri.parse(apiUrl),
      headers: <String, String>{
        'Authorization': storedValue,
      },
      body: ({
        "domainName": selectedDomain,
        "email": email,
        "task": TaskController.text.trim(),
        "deadline": DeadlineController.text.trim(),
      }),
    );
    return response.statusCode == 200;
  }

  Future<void> addTaskAPI(String teamcode) async {
    if (selectedDomain == null || selectedDomain!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Selecciona un área")),
      );
      return;
    }
    if (selectedMembers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Selecciona al menos un miembro")),
      );
      return;
    }
    if (TaskController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Describe la tarea")),
      );
      return;
    }
    if (DeadlineController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Indica la fecha límite")),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final members = selectedMembers.toList();
      final results = await Future.wait(
        members.map((email) => _postTaskFor(teamcode, email)),
      );
      if (!mounted) return;

      final int okCount = results.where((ok) => ok).length;
      final int failCount = results.length - okCount;

      if (okCount > 0) {
        _addedCount += 1;
        // Se limpia la descripción/fecha/miembros para poder cargar la
        // siguiente tarea de una vez; el área elegida se mantiene porque
        // lo normal es seguir agregando tareas para la misma área.
        TaskController.clear();
        DeadlineController.clear();
        setState(() => selectedMembers.clear());
      }

      if (failCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(
            okCount == 1
                ? "Tarea agregada"
                : "Tarea agregada a $okCount miembros",
          )),
        );
      } else if (okCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(
            "Tarea agregada a $okCount de ${members.length} miembros; $failCount falló",
          )),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No se pudo agregar la tarea")),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  TextEditingController TaskController = TextEditingController();
  TextEditingController DeadlineController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final members = _membersForSelectedDomain;
    final bool allSelected = members.isNotEmpty && selectedMembers.length == members.length;

    return AppScaffold(
      appBar: AppBar(
        title: const Text('Agregar tarea'),
        actions: [
          if (_addedCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: AppBadge(
                  label: '$_addedCount agregada${_addedCount == 1 ? '' : 's'}',
                  variant: AppBadgeVariant.success,
                ),
              ),
            ),
        ],
      ),
      scrollable: true,
      body: Form(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.lg),
            DropdownButtonFormField<String>(
              value: selectedDomain,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.domain_outlined),
                hintText: "Área",
              ),
              dropdownColor: AppColors.surface,
              items: _domainNames
                  .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  selectedDomain = value;
                  selectedMembers.clear();
                });
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            // Un área nueva no tiene miembros hasta que alguien la invite
            // (pantalla "Invitar miembros" del equipo) — sin esto, una
            // lista vacía se ve igual que una rota.
            if (selectedDomain != null && members.isEmpty)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 16, color: AppColors.warning),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'El área "$selectedDomain" todavía no tiene miembros invitados. '
                      'Ve al equipo → esa área → "Invitar miembros" para agregar a alguien primero.',
                      style: TextStyle(color: AppColors.warning, fontSize: 12),
                    ),
                  ),
                ],
              )
            else if (selectedDomain != null) ...[
              Row(
                children: [
                  Text(
                    "Asignar a",
                    style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _toggleSelectAllMembers,
                    child: Text(allSelected ? "Quitar todos" : "Seleccionar todos"),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: members.map((m) {
                  final selected = selectedMembers.contains(m);
                  final display = m.contains('@') ? m.substring(0, m.indexOf('@')) : m;
                  return FilterChip(
                    label: Text(display),
                    selected: selected,
                    onSelected: (_) => _toggleMember(m),
                    avatar: selected ? const Icon(Icons.check, size: 16) : null,
                    backgroundColor: AppColors.surface,
                    selectedColor: AppColors.accent.withValues(alpha: 0.25),
                    labelStyle: TextStyle(color: AppColors.textPrimary),
                    side: BorderSide(
                      color: selected ? AppColors.accent : AppColors.surfaceBorder,
                    ),
                  );
                }).toList(),
              ),
              if (selectedMembers.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  "${selectedMembers.length} miembro${selectedMembers.length == 1 ? '' : 's'} seleccionado${selectedMembers.length == 1 ? '' : 's'}",
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ],
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              controller: TaskController,
              prefixIcon: Icon(Icons.add_task_outlined, color: AppColors.textMuted),
              hintText: "Describe la tarea",
            ),
            const SizedBox(height: AppSpacing.lg),
            // Solo lectura a propósito: se llena únicamente con el selector,
            // para que toda tarea nueva quede en formato dd-MM-yyyy (el mismo
            // que ya asumía el resto de la app al mostrar/ordenar por deadline).
            AppTextField(
              controller: DeadlineController,
              prefixIcon: Icon(Icons.calendar_month_outlined, color: AppColors.textMuted),
              hintText: "Fecha límite",
              readOnly: true,
              onTap: _pickDeadline,
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: _submitting ? 'Agregando…' : 'Agregar tarea',
              loading: _submitting,
              onPressed: _submitting ? null : () => addTaskAPI(widget.teamcode),
            ),
            const SizedBox(height: AppSpacing.sm),
            // Para poder cargar varias tareas seguidas: "Agregar tarea" no
            // saca de la pantalla, y este botón cierra explícitamente
            // cuando el admin ya terminó de asignar todas las tareas.
            TextButton(
              onPressed: _submitting
                  ? null
                  : () => Navigator.pushReplacementNamed(context, MyRoutes.BottomNavBar),
              child: Text(_addedCount > 0 ? 'Terminar' : 'Cancelar'),
            ),
          ],
        ),
      ),
    );
  }
}
