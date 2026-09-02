import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../utils/api_config.dart';
import '../screens/login.dart';
import '../design/design.dart';
import 'resource_header.dart';

/// Pantalla "Asistencia para admins": envía un mensaje directo a un admin
/// del equipo. Usa el mismo endpoint que el chat directo (`chat/direct`,
/// ver directChat.dart) — antes apuntaba a `user/sendMessage/{teamId}`,
/// una ruta que no existe en el backend y siempre devolvía 404.
class LeaderResource extends StatefulWidget {
  final String teamId;

  const LeaderResource(this.teamId, {super.key});

  @override
  _LeaderResourceState createState() => _LeaderResourceState();
}

class _LeaderResourceState extends State<LeaderResource> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController messageController = TextEditingController();
  bool _sending = false;

  Future<void> sendMessage() async {
    final to = emailController.text.trim();
    final message = messageController.text.trim();
    if (to.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa el correo y el mensaje.')),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      final storedValue = await secureStorage.readSecureData(key);
      final response = await http.post(
        Uri.parse('$kBaseUrl/chat/direct'),
        headers: <String, String>{
          'Authorization': storedValue ?? '',
        },
        body: {'to': to, 'message': message},
      );

      if (!mounted) return;
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Mensaje enviado con éxito!'),
            duration: Duration(seconds: 2),
          ),
        );
        messageController.clear();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo enviar el mensaje (${response.statusCode})'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error de red al enviar el mensaje')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ResourceHeader(
            title: 'Asistencia para admins',
            subtitle: 'Envía un mensaje directo a un admin del equipo.',
          ),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppTextField(
                  controller: emailController,
                  hintText: 'Correo del admin',
                  textInputType: TextInputType.emailAddress,
                  prefixIcon: Icon(Icons.alternate_email_rounded, color: AppColors.textMuted),
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: messageController,
                  hintText: 'Escribe tu mensaje...',
                  maxLines: 5,
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: 'Enviar mensaje',
                  loading: _sending,
                  onPressed: _sending ? null : sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
