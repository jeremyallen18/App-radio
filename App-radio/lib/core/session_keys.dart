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

/// Estado recordado del check "Recordar" del login ('1' / '0'). Solo sirve para
/// que el check vuelva a aparecer marcado; el correo y la contrasena los guarda
/// el gestor de contrasenas del sistema (Android Autofill / iCloud Llavero), no
/// la app. NO controla la permanencia de la sesion: la sesion sobrevive a
/// cerrar la app y solo termina con "Cerrar sesion".
String rememberMeKey = 'rememberMeFlag';

/// Marca de "el correo de esta cuenta esta verificado" ('1' / '0'). La
/// escribe el login y `Session.fetchCurrentUser`; la lee el aviso de
/// verificacion del shell. Ausente o '1' => no se muestra el aviso (asi las
/// sesiones previas a esta funcion no ven un aviso incorrecto).
String emailVerifiedKey = 'emailVerified';
