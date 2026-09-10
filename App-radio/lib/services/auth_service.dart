import 'package:http/http.dart' as http;

import 'package:doliv_social/core/api_config.dart';

/// Llamadas de autenticación sin token (verificación de correo). El login vive
/// en `login.dart`.
class AuthApi {
  /// Pide reenviar el correo de verificación. Devuelve `true` si respondió 200.
  static Future<bool> resendVerification(String email) async {
    try {
      final res = await http.post(
        Uri.parse('$kBaseUrl/user/resendVerification'),
        body: {'email': email.trim()},
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
