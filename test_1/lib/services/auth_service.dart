import 'package:http/http.dart' as http;

import 'package:doliv_social/core/api_config.dart';

/// Llamadas de autenticación que no necesitan token (registro / verificación
/// de correo). El login vive en `login.dart` por razones históricas.
class AuthApi {
  /// Pide al backend que reenvíe el correo de verificación. El servidor
  /// responde 200 con un mensaje neutro exista o no la cuenta (no filtra si
  /// el correo está registrado) y aplica un límite de envíos.
  ///
  /// Devuelve `true` si la petición se completó (200), sin más detalle.
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
