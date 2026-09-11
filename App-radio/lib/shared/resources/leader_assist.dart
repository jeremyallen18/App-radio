import 'dart:convert';
import 'package:doliv_social/shared/auth/login.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:doliv_social/core/api_config.dart';
import 'package:doliv_social/design/design.dart';

class LeaderResource extends StatefulWidget {
  final String teamId;

  const LeaderResource(this.teamId, {super.key});

  @override
  State<LeaderResource> createState() => _LeaderResourceState();
}

class _LeaderResourceState extends State<LeaderResource> {
  final _formKey = GlobalKey<FormState>();
  TextEditingController emailController = TextEditingController();
  TextEditingController messageController = TextEditingController();
  bool _sending = false;

  Future<void> sendMessage() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _sending = true);
    final storedValue = await secureStorage.readSecureData(key);
    if (storedValue == null || storedValue.trim().isEmpty) {
      if (mounted) setState(() => _sending = false);
      return;
    }

    var headers = {
      'Authorization': storedValue,
      'Content-Type': 'application/json',
    };

    var request = http.Request(
      'POST',
      Uri.parse('$kBaseUrl/user/sendMessage/${widget.teamId}'),
    );
    request.body = json.encode({
      "Correo": emailController.text,
      "message": messageController.text,
    });
    request.headers.addAll(headers);

    try {
      http.StreamedResponse response = await request.send();
      final String responseBody = await response.stream.bytesToString();

      if (!mounted) return;
      if (response.statusCode == 200) {
        debugPrint(responseBody);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Mensaje enviado con éxito!'),
            duration: Duration(seconds: 2),
          ),
        );
        emailController.clear();
        messageController.clear();
      } else {
        debugPrint(response.reasonPhrase);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo enviar el mensaje. Inténtalo de nuevo.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        title: const Text('Asistencia del líder'),
        automaticallyImplyLeading: false,
      ),
      scrollable: true,
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Envía un mensaje directo al líder de tu equipo para pedir ayuda o resolver una duda.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppTextField(
              controller: emailController,
              prefixIcon:
                  Icon(Icons.email_outlined, color: AppColors.textMuted),
              hintText: 'Correo del líder',
              textInputType: TextInputType.emailAddress,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Indica el correo del líder'
                  : null,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              controller: messageController,
              prefixIcon:
                  Icon(Icons.message_outlined, color: AppColors.textMuted),
              hintText: 'Escribe tu mensaje',
              maxLines: 5,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Escribe un mensaje' : null,
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: _sending ? 'Enviando…' : 'Enviar mensaje',
              loading: _sending,
              onPressed: _sending ? null : sendMessage,
            ),
          ],
        ),
      ),
    );
  }
}
