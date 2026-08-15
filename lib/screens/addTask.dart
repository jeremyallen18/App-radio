import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../design/design.dart';
import '../Utils/Routes.dart';
import 'login.dart';
import '../utils/api_config.dart';

class addTask extends StatefulWidget {
  addTask({super.key, required this.teamcode, this.domains});
  dynamic teamcode;
  final List<dynamic>? domains;

  @override
  State<addTask> createState() => _addTaskState();
}

class _addTaskState extends State<addTask> {
  String? selectedDomain;
  String? selectedMember;
  bool _submitting = false;

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

  Future<void> addTaskAPI(String teamcode) async {
    if (selectedDomain == null || selectedDomain!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Selecciona un área")),
      );
      return;
    }
    if (selectedMember == null || selectedMember!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Selecciona un miembro")),
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
    dynamic storedValue = await secureStorage.readSecureData(key);
    final String apiUrl = '$kBaseUrl/team/task/$teamcode';
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: <String, String>{
          'Authorization': storedValue,
        },
        body: ({
          "domainName": selectedDomain,
          "email": selectedMember,
          "task": TaskController.text,
          "deadline": DeadlineController.text,
        }),
      );

      if (!mounted) return;
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Tarea agregada")),
        );
        Navigator.pushReplacementNamed(context, MyRoutes.BottomNavBar);
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
    return AppScaffold(
      appBar: AppBar(
        title: const Text('Agregar tarea'),
        leading: AppBackButton.leadingFor(context),
        automaticallyImplyLeading: false,
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
                  selectedMember = null;
                });
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            DropdownButtonFormField<String>(
              value: selectedMember,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.person_outline),
                hintText: selectedDomain == null ? "Elige un área primero" : "Miembro",
              ),
              dropdownColor: AppColors.surface,
              items: _membersForSelectedDomain
                  .map((m) => DropdownMenuItem(value: m, child: Text(m, overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: selectedDomain == null
                  ? null
                  : (value) => setState(() => selectedMember = value),
            ),
            // Un área nueva no tiene miembros hasta que alguien la invite
            // (pantalla "Invitar miembros" del equipo) — sin esto, un
            // dropdown vacío se ve igual que uno roto.
            if (selectedDomain != null && _membersForSelectedDomain.isEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 16, color: AppColors.warning),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'El área "$selectedDomain" todavía no tiene miembros invitados. '
                      'Ve al equipo → esa área → "Invitar miembros" para agregar a alguien primero.',
                      style: const TextStyle(color: AppColors.warning, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              controller: TaskController,
              prefixIcon: const Icon(Icons.add_task_outlined, color: AppColors.textMuted),
              hintText: "Describe la tarea",
            ),
            const SizedBox(height: AppSpacing.lg),
            // Solo lectura a propósito: se llena únicamente con el selector,
            // para que toda tarea nueva quede en formato dd-MM-yyyy (el mismo
            // que ya asumía el resto de la app al mostrar/ordenar por deadline).
            AppTextField(
              controller: DeadlineController,
              prefixIcon: const Icon(Icons.calendar_month_outlined, color: AppColors.textMuted),
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
          ],
        ),
      ),
    );
  }
}
