import "package:flutter/material.dart";
import 'package:http/http.dart' as http;
import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/core/routes.dart';
import 'package:doliv_social/models/join_model.dart';
import 'package:doliv_social/shared/auth/login.dart';
import 'package:doliv_social/core/api_config.dart';

class JoinTeamScreen extends StatefulWidget {
  const JoinTeamScreen({super.key});

  @override
  State<JoinTeamScreen> createState() => _JoinTeamScreenState();
}

class _JoinTeamScreenState extends State<JoinTeamScreen> {
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
          const SnackBar(
              content: Text('No se pudo unir al equipo. Verifica el código.')),
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
            Text(
              "Unirse a equipo",
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 32,
                  fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              "Pídele el código a quien lidera el equipo",
              style: TextStyle(color: AppColors.textMuted, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            AppTextField(
              controller: teamCodeController,
              prefixIcon:
                  Icon(Icons.group_outlined, color: AppColors.textMuted),
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
