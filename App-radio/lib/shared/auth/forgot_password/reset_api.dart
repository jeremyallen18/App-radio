import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:doliv_social/core/api_config.dart';

/// Pide al backend que genere y envíe el código de recuperación a [email].
/// Devuelve `null` si salió bien, o el mensaje de error para mostrar.
/// Lo usan tanto la pantalla de "Recuperar" como el "Reenviar código".
Future<String?> sendResetCode(String email) async {
  const String apiUrl = '$kBaseUrl/user/resetPassword';
  try {
    final response = await http.post(
      Uri.parse(apiUrl),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
    if (response.statusCode == 200) return null;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['error'] != null) {
        return decoded['error'].toString();
      }
    } catch (_) {}
    return 'No se pudo enviar el código (${response.statusCode})';
  } catch (_) {
    return 'Sin conexión con el servidor';
  }
}
