import "package:flutter/material.dart";
import 'package:http/http.dart' as http;
import "../Utils/Routes.dart";
import "login.dart";
import '../utils/api_config.dart';
import '../design/design.dart';

class doneTask extends StatefulWidget {
  const doneTask({super.key});

  @override
  State<doneTask> createState() => _doneTaskState();
}

class _doneTaskState extends State<doneTask> {
  final _formKey = GlobalKey<FormState>();
  bool _submitting = false;

  Future<void> TaskDoneAPI() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _submitting = true);
    dynamic storedValue = await secureStorage.readSecureData(key);
    const String apiUrl = '$kBaseUrl/team/taskDone';
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: <String, String>{
          'Authorization': storedValue,
        },
        body: ({
          "teamCode": TeamCodeController.text,
          "domainName": DomainController.text,
          "email": EmailController.text,
          "task": TaskController.text,
        }),
      );

      if (!mounted) return;
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Tarea marcada como hecha")),
        );
        Navigator.pushReplacementNamed(context, MyRoutes.BottomNavBar);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("No se pudo marcar la tarea (${response.statusCode})")),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error de red al marcar la tarea")),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  TextEditingController EmailController = TextEditingController();
  TextEditingController DomainController = TextEditingController();
  TextEditingController TaskController = TextEditingController();
  TextEditingController TeamCodeController = TextEditingController();

  String? _required(String? value, String message) {
    if (value == null || value.trim().isEmpty) return message;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        title: const Text('Marcar tarea como hecha'),
        leading: AppBackButton.leadingFor(context),
        automaticallyImplyLeading: false,
      ),
      scrollable: true,
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'Indica el equipo, área y tarea que quieres marcar como completada.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppTextField(
              controller: TeamCodeController,
              prefixIcon: const Icon(Icons.groups_outlined, color: AppColors.textMuted),
              hintText: "Código de equipo",
              validator: (v) => _required(v, "Indica el código de equipo"),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              controller: DomainController,
              prefixIcon: const Icon(Icons.domain_outlined, color: AppColors.textMuted),
              hintText: "Área",
              validator: (v) => _required(v, "Indica el área"),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              controller: EmailController,
              prefixIcon: const Icon(Icons.email_outlined, color: AppColors.textMuted),
              hintText: "Correo de la persona asignada",
              textInputType: TextInputType.emailAddress,
              validator: (v) => _required(v, "Indica el correo"),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              controller: TaskController,
              prefixIcon: const Icon(Icons.add_task_outlined, color: AppColors.textMuted),
              hintText: "Descripción de la tarea",
              validator: (v) => _required(v, "Indica la tarea"),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: _submitting ? 'Marcando…' : 'Marcar como hecha',
              loading: _submitting,
              onPressed: _submitting ? null : TaskDoneAPI,
            ),
          ],
        ),
      ),
    );
  }
}
