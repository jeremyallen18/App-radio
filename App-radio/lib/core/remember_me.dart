import 'package:doliv_social/core/session_keys.dart';

/// Recuerda únicamente el estado del check "Recordar" del login entre aperturas
/// de la app.
///
/// El correo y la contraseña NO se guardan aquí: cuando el check está activo, el
/// login le pide al gestor de contraseñas del sistema (Android Autofill /
/// iCloud Llavero) que los guarde, y es ese gestor quien los ofrece la próxima
/// vez. La app nunca los lee ni los repinta en los campos.
///
/// Esto no interviene en la permanencia de la sesión: la sesión sobrevive a
/// cerrar la app y solo termina con "Cerrar sesión".
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
