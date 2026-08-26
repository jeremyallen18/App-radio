import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../Utils/Routes.dart';
import 'login.dart';
import '../utils/api_config.dart';
import '../design/design.dart';

class Mresign extends StatefulWidget {
  Mresign({super.key, required this.teamId, required this.emailId});
  String? teamId;
  String? emailId;

  @override
  State<Mresign> createState() => _MresignState();
}

class _MresignState extends State<Mresign> {
  final _formKey = GlobalKey<FormState>();
  bool _submitting = false;

  Future<void> MresignApi(String? teamId, String? email) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _submitting = true);
    dynamic storedValue = await secureStorage.readSecureData(key);
    final String apiUrl = '$kBaseUrl/user/sendMessage/$teamId';
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: <String, String>{
          'Authorization': storedValue,
        },
        body: ({
          "Correo": email,
          "message": MessageController.text,
        }),
      );

      if (!mounted) return;
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Correo enviado")),
        );
        Navigator.pushReplacementNamed(context, MyRoutes.BottomNavBar);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("No se pudo enviar la renuncia (${response.statusCode})")),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error de red al enviar la renuncia")),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  TextEditingController MessageController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        title: const Text('Renunciar al equipo'),
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
              'Se le enviará un correo a tu líder de equipo con el mensaje que escribas.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppTextField(
              controller: MessageController,
              prefixIcon: const Icon(Icons.edit_note_outlined, color: AppColors.textMuted),
              hintText: "Mensaje para el líder",
              maxLines: 5,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? "Escribe un mensaje para el líder" : null,
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: _submitting ? 'Enviando…' : 'Enviar renuncia',
              loading: _submitting,
              onPressed: _submitting ? null : () => MresignApi(widget.teamId, widget.emailId),
            ),
          ],
        ),
      ),
    );
  }
}
