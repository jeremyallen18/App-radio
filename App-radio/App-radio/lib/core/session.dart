// Obtiene y cachea el perfil (rol/departamento) del usuario autenticado.
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:doliv_social/models/models.dart';
import 'package:doliv_social/core/store_token.dart';
import 'package:doliv_social/core/api_config.dart';
import 'package:doliv_social/core/session_keys.dart' show secureStorage, emailVerifiedKey;

class Session {
  static const String _roleKey = 'userRole';
  static final SecureStorage _storage = SecureStorage();

  /// GET /user/me → perfil, o null si falla. No lanza (no romper el login).
  static Future<UserProfile?> fetchCurrentUser(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$kBaseUrl/user/me'),
        headers: {'Authorization': token},
      );
      if (response.statusCode != 200) return null;
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final profile = UserProfile.fromJson(json);
      await _storage.writeSecureData(_roleKey, profile.role.name);
      // Mantiene fresca la marca de verificación de correo que lee el shell.
      await secureStorage.writeSecureData(
          emailVerifiedKey, profile.emailVerified ? '1' : '0');
      return profile;
    } catch (_) {
      return null;
    }
  }

  static Future<AppRole?> getCachedRole() async {
    final stored = await _storage.readSecureData(_roleKey);
    if (stored == null) return null;
    return appRoleFromString(stored as String);
  }

  /// Rol actual desde `/user/me` (refresca el caché); si la llamada falla, cae
  /// al valor cacheado.
  static Future<AppRole?> getFreshRole(String? token) async {
    if (token != null) {
      final profile = await fetchCurrentUser(token);
      if (profile != null) return profile.role;
    }
    return getCachedRole();
  }
}
