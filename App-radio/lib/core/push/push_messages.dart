/// Utilidades puras para decidir qué hacer con un mensaje push recibido.
/// Sin dependencias de Firebase: se prueban con `flutter test`.
library;

/// Normaliza el `data` de un mensaje (claves/valores arbitrarios) a
/// `String -> String`. Un valor `null` se vuelve `''`.
Map<String, String> normalizePushData(Map<Object?, Object?> raw) {
  final out = <String, String>{};
  raw.forEach((key, value) {
    if (key != null) {
      out[key.toString()] = value?.toString() ?? '';
    }
  });
  return out;
}

/// `false` solo cuando el mensaje es de un chat cuyo hilo el usuario tiene
/// abierto ahora mismo (se refresca el badge, sin toast). `true` en el resto.
bool shouldShowLocalNotification(
  Map<String, String> data,
  String? activeChatPeerEmail,
) {
  if (data['type'] == 'chat') {
    final peer = data['entityId'];
    if (peer != null && peer.isNotEmpty && peer == activeChatPeerEmail) {
      return false;
    }
  }
  return true;
}

/// Id estable y no negativo (31 bits) para la notificación local, derivado de
/// `tipo:entidad`, de modo que mensajes repetidos del mismo remitente/entidad
/// se reemplacen en la bandeja en vez de apilarse. FNV-1a de 32 bits.
///
/// Muchos emisores del backend no traen `entityId`; en ese caso se siembra el
/// hash con `notifId` (único por notificación) para que no colisionen todos.
int localNotificationId(Map<String, String> data) {
  final entityId = data['entityId'];
  final entity = (entityId != null && entityId.isNotEmpty)
      ? entityId
      : (data['notifId'] ?? '');
  final seed = '${data['type'] ?? ''}:$entity';
  var hash = 0x811c9dc5;
  for (final unit in seed.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash & 0x7fffffff;
}
