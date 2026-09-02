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
  static const String _emailKey = 'userEmail';
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
      await _storage.writeSecureData(_emailKey, profile.email);
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

  /// Correo del usuario autenticado, cacheado en almacenamiento seguro (por
  /// lo tanto persiste entre reinicios de la app, a diferencia de una
  /// variable global en memoria). Se llena en login y cada vez que se llama
  /// a fetchCurrentUser(). Usado para saber "quién soy" de forma confiable
  /// en pantallas como el detalle de equipo (para reconocer al admin/líder
  /// al instante) y el chat.
  static Future<String?> getCachedEmail() async {
    final stored = await _storage.readSecureData(_emailKey);
    return stored as String?;
  }

  static Future<void> cacheEmail(String email) async {
    await _storage.writeSecureData(_emailKey, email);
  }

  /// Borra el correo y rol cacheados. Debe llamarse siempre al cerrar
  /// sesión: si no se limpia, y otra persona inicia sesión después en el
  /// mismo dispositivo, la app podría reconocerla por error con la
  /// identidad (y el estado de "soy el líder/admin") de quien salió antes.
  static Future<void> clearCache() async {
    await _storage.deleteSecureData(_roleKey);
    await _storage.deleteSecureData(_emailKey);
  }

  /// Devuelve el correo cacheado si existe; si no, lo pide a /user/me con
  /// el token guardado y lo cachea. Devuelve null solo si no hay sesión o
  /// si la petición falla.
  static Future<String?> resolveEmail(String? token) async {
    final cached = await getCachedEmail();
    if (cached != null && cached.isNotEmpty) return cached;
    if (token == null || token.isEmpty) return null;
    final profile = await fetchCurrentUser(token);
    return profile?.email;
  }
}
