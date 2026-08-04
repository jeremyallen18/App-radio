import 'dart:convert';
import 'package:brl_task4/create&join-Team/Domain-team.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';
import '../design/design.dart';
import '../screens/login.dart';
import '../utils/api_config.dart';

class Domain {
  final int id;
  final String name;

  Domain({required this.id, required this.name});
}

class CreateTeamScreen extends StatefulWidget {
  const CreateTeamScreen({super.key});

  @override
  _CreateTeamScreenState createState() => _CreateTeamScreenState();
}

class _CreateTeamScreenState extends State<CreateTeamScreen> {
  TextEditingController teamNameController = TextEditingController();

  final List<Domain> domains = [
    Domain(id: 1, name: 'Backend'),
    Domain(id: 2, name: 'Frontend'),
    Domain(id: 3, name: 'Machine Learning'),
    Domain(id: 4, name: 'App Development'),
  ];

  List<Domain> selectedDomains = [];
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(title: const Text('Crear equipo')),
      scrollable: true,
      body: Form(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              controller: teamNameController,
              prefixIcon: const Icon(Icons.groups_outlined, color: AppColors.textMuted),
              hintText: 'Nombre del equipo',
            ),
            const SizedBox(height: AppSpacing.lg),
            MultiSelectDialogField<Domain>(
              items: domains.map((d) => MultiSelectItem<Domain>(d, d.name)).toList(),
              initialValue: selectedDomains,
              title: const Text('Seleccionar áreas'),
              searchable: false,
              backgroundColor: AppColors.surface,
              selectedColor: AppColors.accent,
              checkColor: AppColors.textPrimary,
              itemsTextStyle: const TextStyle(color: AppColors.textPrimary),
              selectedItemsTextStyle: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700),
              unselectedColor: AppColors.textMuted,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.field),
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              buttonIcon: const Icon(Icons.domain_outlined, color: AppColors.textMuted),
              buttonText: Text(
                selectedDomains.isEmpty
                    ? 'Seleccionar áreas'
                    : selectedDomains.map((d) => d.name).join(', '),
                style: TextStyle(
                  color: selectedDomains.isEmpty ? AppColors.textMuted : AppColors.textPrimary,
                  fontSize: 14,
                ),
              ),
              confirmText: const Text('Confirmar', style: TextStyle(color: AppColors.accentStrong)),
              cancelText: const Text('Cancelar', style: TextStyle(color: AppColors.textMuted)),
              onConfirm: (values) {
                // Bug real que corregí: faltaba este setState — la selección
                // quedaba guardada pero el botón nunca mostraba qué se eligió,
                // así que parecía que no se podía seleccionar nada.
                setState(() => selectedDomains = values);
              },
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: _submitting ? 'Creando…' : 'Crear equipo',
              loading: _submitting,
              onPressed: _submitting ? null : _handleCreate,
            ),
          ],
        ),
      ),
    );
  }

  void _handleCreate() {
    if (teamNameController.text.trim().isEmpty) {
      _showErrorSnackBar('El nombre del equipo no puede estar vacío');
      return;
    }
    if (selectedDomains.isEmpty) {
      _showErrorSnackBar('Selecciona al menos un área');
      return;
    }
    createTeam();
  }

  Future<void> createTeam() async {
    setState(() => _submitting = true);
    dynamic storedValue = await secureStorage.readSecureData(key);
    var headers = <String, String>{
      'Authorization': storedValue,
      'Content-Type': 'application/json',
    };
    var request = http.Request(
      'POST',
      Uri.parse('$kBaseUrl/team/createTeam'),
    );

    final List<Map<String, dynamic>> domainList = selectedDomains.map((domain) {
      return {
        "name": domain.name,
        "members": [],
      };
    }).toList();

    request.body = json.encode({
      "teamName": teamNameController.text,
      "domains": domainList,
    });

    request.headers.addAll(headers);

    try {
      http.StreamedResponse response = await request.send();
      if (!mounted) return;

      if (response.statusCode == 200) {
        final String responseBody = await response.stream.bytesToString();
        final Map<String, dynamic> responseData = jsonDecode(responseBody);
        final String teamId = responseData['team']['_id'];

        _showErrorSnackBar('Equipo creado con éxito');
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TeamDetailsScreen(teamNameController.text, selectedDomains, teamId),
          ),
        );
      } else {
        _showErrorSnackBar(response.reasonPhrase ?? 'No se pudo crear el equipo');
      }
    } catch (error) {
      if (!mounted) return;
      _showErrorSnackBar('Error al crear el equipo: $error');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showErrorSnackBar(String errorMessage) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(errorMessage),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Descartar',
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }
}
