import 'package:doliv_social/core/session_keys.dart';

/// Persiste solo el estado del check "Recordar" del login. Las credenciales las
/// guarda el gestor del sistema (Android Autofill / Llavero), no la app. No
/// afecta a la permanencia de la sesión.
class RememberMe {
  const RememberMe._();

  /// `true` si el usuario dejó el check "Recordar" activo la última vez.
  static Future<bool> loadFlag() async {
    final flag = await secureStorage.readSecureData(rememberMeKey);
    return flag == '1';
  }

  /// Persiste el estado del check tras un login correcto.
  static Future<void> saveFlag(bool remember) =>
      secureStorage.writeSecureData(rememberMeKey, remember ? '1' : '0');
}
