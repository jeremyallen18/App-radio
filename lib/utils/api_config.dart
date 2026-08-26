// URLs del backend, configurables por --dart-define para no tener que tocar
// código al cambiar de red o de entorno (dev/staging/prod):
//
//   flutter run \
//     --dart-define=BASE_URL=http://192.168.1.50/hive-backend \
//     --dart-define=SITE_BASE_URL=http://192.168.1.50/RADIODOLIV_PAGINA/
//
// Sin esos flags, cae a la IP de LAN de desarrollo de siempre para que
// `flutter run` sin argumentos siga funcionando igual que antes.
const String kBaseUrl = String.fromEnvironment(
  'BASE_URL',
  defaultValue: 'http://192.168.3.74/hive-backend',
);

// Raíz pública de RADIODOLIV_PAGINA (mismo host, proyecto hermano bajo
// htdocs). Se usa solo para construir la URL completa de las imágenes que
// devuelve /site/* (rutas relativas tipo "assets/img/eventos/foo.jpg").
const String kSiteBaseUrl = String.fromEnvironment(
  'SITE_BASE_URL',
  defaultValue: 'http://192.168.3.74/RADIODOLIV_PAGINA/',
);
