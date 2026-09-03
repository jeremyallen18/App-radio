// URLs del backend, configurables por --dart-define para no tener que tocar
// código al cambiar de red o de entorno (dev/staging/prod):
//
//   flutter run \
//     --dart-define=BASE_URL=http://192.168.100.250/hive-backend \
//     --dart-define=SITE_BASE_URL=http://192.168.100.250/radio-doliv/RADIODOLIV_PAGINA/
//
// Sin esos flags, cae a la IP de LAN de desarrollo de siempre para que
// `flutter run` sin argumentos siga funcionando igual que antes.
//
// `hive-backend` se sirve por un Alias de Apache (`/hive-backend` ->
// .../radio-doliv/App-radio/hive-backend), así que su URL NO cambió al mover
// los proyectos dentro de radio-doliv/. `RADIODOLIV_PAGINA` se sirve por
// ruta, así que su URL local ahora lleva el prefijo /radio-doliv/.
const String kBaseUrl = String.fromEnvironment(
  'BASE_URL',
  defaultValue: 'http://192.168.3.44/hive-backend',
);

// Raíz pública de RADIODOLIV_PAGINA (mismo host, proyecto hermano dentro de
// htdocs/radio-doliv/). Se usa solo para construir la URL completa de las
// imágenes que devuelve /site/* (rutas relativas tipo
// "assets/img/eventos/foo.jpg").
const String kSiteBaseUrl = String.fromEnvironment(
  'SITE_BASE_URL',
  defaultValue: 'http://192.168.3.44/radio-doliv/RADIODOLIV_PAGINA/',
);
