// URLs del backend, configurables por --dart-define (BASE_URL, SITE_BASE_URL).
// Sin flags, caen a la IP de LAN de desarrollo.
const String kBaseUrl = String.fromEnvironment(
  'BASE_URL',
  defaultValue: 'http://192.168.100.250/hive-backend',
);

// Raíz pública de RADIODOLIV_PAGINA; solo para completar la URL de las imágenes
// que devuelve /site/*.
const String kSiteBaseUrl = String.fromEnvironment(
  'SITE_BASE_URL',
  defaultValue: 'http://192.168.100.250/radio-doliv/RADIODOLIV_PAGINA/',
);
