import 'package:doliv_social/core/store_token.dart';

/// Claves de almacenamiento seguro y storage compartido de la sesión, usados en
/// toda la app. `login.dart` las re-exporta.
final SecureStorage secureStorage = SecureStorage();

/// Clave del token de acceso en el almacenamiento seguro.
String key = 'accessToken';

/// Estado del check "Recordar" del login ('1' / '0'). Solo controla que el check
/// reaparezca marcado; no la permanencia de la sesión.
String rememberMeKey = 'rememberMeFlag';

/// Marca "correo verificado" ('1' / '0'), leída por el aviso del shell. Ausente
/// o '1' ⇒ no se muestra el aviso.
String emailVerifiedKey = 'emailVerified';
