import "package:flutter/material.dart";
import 'package:http/http.dart' as http;
import "../design/design.dart";
import "../utils/Routes.dart";
import "../models/join_model.dart";
import "../screens/login.dart";
import '../utils/api_config.dart';

class join_team extends StatefulWidget {
  const join_team({super.key});

  @override
  State<join_team> createState() => _join_teamState();
}

class _join_teamState extends State<join_team> {
  final TextEditingController teamCodeController = TextEditingController();
  bool _joining = false;

  Future<void> joinTeamAPI() async {
    if (teamCodeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un código de equipo')),
      );
      return;
    }

    setState(() => _joining = true);
    dynamic storedValue = await secureStorage.readSecureData(key);
    const String apiUrl = '$kBaseUrl/team/joinTeam';
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: <String, String>{
          'Authorization': storedValue,
          'Content-Type': 'application/json',
        },
        body: joinTeamToJson(
          JoinTeam(teamCode: teamCodeController.text),
        ),
      );

      if (!mounted) return;
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Te uniste al equipo con éxito")),
        );
        Navigator.pushReplacementNamed(context, MyRoutes.dashbMemRoutes);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo unir al equipo. Verifica el código.')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error de red al unirte al equipo')),
      );
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      scrollable: true,
      body: Form(
        child: Column(
          children: [
            const SizedBox(height: 80),
            const Text(
              "Unirse a equipo",
              style: TextStyle(color: AppColors.textPrimary, fontSize: 32, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              "Pídele el código a quien lidera el equipo",
              style: TextStyle(color: AppColors.textMuted, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            AppTextField(
              controller: teamCodeController,
              prefixIcon: const Icon(Icons.group_outlined, color: AppColors.textMuted),
              hintText: "Código de equipo",
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: _joining ? 'Uniéndose…' : 'Unirse a equipo',
              loading: _joining,
              onPressed: _joining ? null : joinTeamAPI,
            ),
          ],
        ),
      ),
    );
  }
}
