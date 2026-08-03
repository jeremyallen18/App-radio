// Sesión organizacional: obtiene y cachea el perfil (rol/departamento) del
// usuario autenticado. El equipo a cargo de los dashboards por rol puede
// leer el rol cacheado con `Session.getCachedRole()` para decidir qué
// pantalla mostrar, sin tener que llamar de nuevo a /user/me.
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/models.dart';
import '../models/storeToken.dart';
import 'api_config.dart';

class Session {
  static const String _roleKey = 'userRole';
  static final SecureStorage _storage = SecureStorage();

  /// Llama a GET /user/me y devuelve el perfil, o null si falla (por
  /// ejemplo si el backend aún no tiene la empresa configurada o el token
  /// expiró). No lanza excepciones para no romper el flujo de login.
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
}
