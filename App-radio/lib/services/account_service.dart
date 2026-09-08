import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:doliv_social/core/api_config.dart';
import 'package:doliv_social/core/session_keys.dart' show secureStorage, key;
import 'package:doliv_social/models/company.dart';
import 'package:doliv_social/models/models.dart';

/// Error de autoservicio de cuenta, con mensaje en español listo para mostrar.
class AccountException implements Exception {
  AccountException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Autoservicio de cuenta (migración 029) + nombre de la empresa: lo que el
/// usuario puede cambiar de sí mismo desde el perfil.
///
/// - `updateName` / `changePassword` / `requestEmailChange` / `cancelEmailChange`
///   -> `/user/account/*` (auth.php).
/// - `updateCompanyName` -> `/company/update` (org.php, solo director).
class AccountApi {
  static Future<String> _token() async {
    final t = await secureStorage.readSecureData(key);
    return (t as String?) ?? '';
  }

  static Future<Map<String, dynamic>> _post(
    String path,
    Map<String, String> body,
  ) async {
    late final http.Response res;
    try {
      res = await http.post(
        Uri.parse('$kBaseUrl$path'),
        headers: {'Authorization': await _token()},
        body: body,
      );
    } catch (_) {
      throw AccountException(
          'No se pudo completar la operación por un error de conexión.');
    }
    Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      decoded = const {};
    }
    if (res.statusCode != 200) {
      throw AccountException(
        (decoded['error'] ?? decoded['message'])?.toString() ??
            'No se pudo completar la operación. Inténtalo nuevamente.',
      );
    }
    return decoded;
  }

  /// Cambia el nombre visible del usuario. Devuelve el perfil actualizado.
  static Future<UserProfile> updateName(String name) async {
    final json = await _post('/user/account/name', {'name': name.trim()});
    return UserProfile.fromJson(json);
  }

  /// Cambia la contraseña. El backend rota el token de acceso; aquí se
  /// re-guarda para no cerrar la sesión en la siguiente petición.
  static Future<void> changePassword({
    required String current,
    required String next,
    required String confirm,
  }) async {
    final json = await _post('/user/account/password', {
      'currentPassword': current,
      'newPassword': next,
      'confirmPassword': confirm,
    });
    final token = json['token']?.toString();
    if (token != null && token.isNotEmpty) {
      await secureStorage.writeSecureData(key, token);
    }
  }

  /// Pide el cambio de correo: el backend manda un enlace de confirmación al
  /// correo nuevo y deja `pending_email` hasta que se abra. Devuelve el
  /// mensaje del servidor para mostrarlo tal cual.
  static Future<String> requestEmailChange({
    required String current,
    required String newEmail,
  }) async {
    final json = await _post('/user/account/email', {
      'currentPassword': current,
      'newEmail': newEmail.trim(),
    });
    return json['message']?.toString() ??
        'Te enviamos un enlace para confirmar el cambio.';
  }

  /// Cancela un cambio de correo pendiente. Devuelve el perfil actualizado.
  static Future<UserProfile> cancelEmailChange() async {
    final json = await _post('/user/account/email/cancel', const {});
    return UserProfile.fromJson(json);
  }

  /// Cambia el nombre de la empresa (solo director). Devuelve la empresa.
  static Future<Company> updateCompanyName(String name) async {
    final json = await _post('/company/update', {'name': name.trim()});
    return Company.fromJson(Map<String, dynamic>.from(json['company'] as Map));
  }
}
