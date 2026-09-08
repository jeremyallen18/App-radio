import 'package:doliv_social/core/store_token.dart';

/// Claves de almacenamiento seguro y storage compartido de la sesion.
///
/// Antes vivian como variables top-level dentro de `login.dart`; se
/// centralizan aca porque las consumen servicios, clientes de API,
/// `main.dart` y varias pantallas en toda la app. `login.dart` las
/// re-exporta para no romper los imports existentes.
final SecureStorage secureStorage = SecureStorage();

/// Clave del token de acceso en el almacenamiento seguro.
String key = 'accessToken';

/// Marca de "mantener sesion iniciada" entre aperturas de la app. `main.dart`
/// la revisa al arrancar: si quedo en "0", borra el token y manda a Login.
String rememberMeKey = 'rememberMeFlag';

/// Marca de "el correo de esta cuenta esta verificado" ('1' / '0'). La
/// escribe el login y `Session.fetchCurrentUser`; la lee el aviso de
/// verificacion del shell. Ausente o '1' => no se muestra el aviso (asi las
/// sesiones previas a esta funcion no ven un aviso incorrecto).
String emailVerifiedKey = 'emailVerified';
