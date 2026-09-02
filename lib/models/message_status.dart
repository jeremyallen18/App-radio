/// Estado de un mensaje de chat, al estilo WhatsApp.
///
/// Dos orígenes:
/// - [sending] y [failed] son locales: describen qué está pasando con la
///   petición HTTP mientras todavía no hay confirmación del servidor
///   (ver `_PendingMessage` en chat.dart / directChat.dart).
/// - [sent], [delivered] y [read] los calcula el backend (ver
///   `chat_message_status()` en hive-backend/index.php) y llegan en el
///   campo `status` de cada mensaje propio.
enum MessageStatus {
  /// Mensaje en camino: la petición POST todavía no responde.
  sending,

  /// Se está reintentando el envío después de un error.
  retrying,

  /// El envío falló y no se reintentó (aún): "mensaje no entregado".
  failed,

  /// El servidor confirmó la escritura (200), pero el mensaje todavía no
  /// aparece en la copia oficial que devuelve el chat (ventana muy breve,
  /// mientras se refresca la conversación).
  sent,

  /// El mensaje ya está guardado en el servidor. Como no hay
  /// notificaciones push, esto es lo más parecido a "entregado" que se
  /// puede afirmar: el resto de los dispositivos lo van a traer en su
  /// próximo sondeo.
  delivered,

  /// Todos los destinatarios marcaron el chat como leído después de que
  /// se envió el mensaje.
  read;

  /// Convierte el campo `status` que manda el backend ('delivered' |
  /// 'read') al enum. Cualquier otro valor cae en [delivered], que es el
  /// estado "seguro" para un mensaje que ya llegó al servidor.
  static MessageStatus fromServer(String? raw) {
    switch (raw) {
      case 'read':
        return MessageStatus.read;
      case 'delivered':
      default:
        return MessageStatus.delivered;
    }
  }

  /// Si en esta app tuviera sentido mostrar el estado (solo en los
  /// mensajes propios), esto es lo que se ve al lado de la hora.
  bool get isTerminalError => this == MessageStatus.failed;
}
