import 'package:flutter/material.dart';
import 'identity_avatar.dart';
import '../../models/message_status.dart';
import '../tokens/colors.dart';
import '../tokens/spacing.dart';

/// Burbuja de mensaje de chat, estilo Slack/Discord: avatar + nombre para
/// los mensajes de otras personas, alineado a la izquierda; los propios,
/// alineados a la derecha, con degradado de marca y sin avatar repetido.
///
/// Si se pasa [time] (formateado como "HH:mm"), se muestra pequeño en la
/// esquina inferior derecha de la burbuja, al estilo WhatsApp. Los
/// separadores de día ("HOY", "AYER", etc.) van aparte, en [DayDivider].
///
/// Si se pasa [status] (solo tiene sentido cuando [isMe] es true, igual
/// que en WhatsApp: los indicadores de estado son de MIS mensajes), se
/// dibuja el indicador correspondiente junto a la hora: reloj mientras se
/// envía, ✓ enviado, ✓✓ entregado, ✓✓ azul leído, o un ícono de error
/// (con [onRetry]) si el envío falló.
///
/// Si se pasa [replyTo] (con las claves 'name' y 'message'), se dibuja
/// arriba del texto una pequeña cita del mensaje original, al estilo
/// WhatsApp, para dejar claro a qué mensaje se está respondiendo.
///
/// Si se pasa [onReply], se puede mantener presionada la burbuja para
/// elegir "responder" a ese mensaje puntual.
class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.username,
    required this.message,
    required this.isMe,
    this.displayName,
    this.photoUrl,
    this.time,
    this.status,
    this.onRetry,
    this.replyTo,
    this.onReply,
  });

  final String username;
  final String message;
  final bool isMe;

  /// Nombre real del remitente (viene de `users.name` en el backend). Si no
  /// llega (p. ej. la cuenta ya no existe), se cae de vuelta al correo.
  final String? displayName;

  /// Foto de perfil del remitente, si tiene una subida. Sin ella, el avatar
  /// muestra la inicial.
  final String? photoUrl;

  /// Hora del mensaje ya formateada (p. ej. "17:27"), al estilo WhatsApp:
  /// se muestra pequeña, en la esquina inferior derecha de la burbuja. Si
  /// no llega, la burbuja no muestra ninguna hora.
  final String? time;

  /// Estado de entrega/lectura del mensaje. Solo se dibuja cuando [isMe]
  /// es true.
  final MessageStatus? status;

  /// Se llama al tocar el indicador de error ([MessageStatus.failed]),
  /// para reintentar el envío de ese mensaje.
  final VoidCallback? onRetry;

  /// Mensaje original al que responde este, si corresponde. Debe traer
  /// las claves 'name' (autor del mensaje citado) y 'message' (su texto).
  final Map<String, String>? replyTo;

  /// Se llama al mantener presionada la burbuja, para elegir responder a
  /// este mensaje. Si es null, la burbuja no reacciona a la presión larga.
  final VoidCallback? onReply;

  @override
  Widget build(BuildContext context) {
    final name = (displayName != null && displayName!.trim().isNotEmpty)
        ? displayName!.trim()
        : (username.contains('@') ? username.substring(0, username.indexOf('@')) : username);

    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(AppRadius.card),
      topRight: const Radius.circular(AppRadius.card),
      bottomLeft: Radius.circular(isMe ? AppRadius.card : 4),
      bottomRight: Radius.circular(isMe ? 4 : AppRadius.card),
    );

    final showFooter = (time != null && time!.isNotEmpty) || (isMe && status != null);

    // Ancho máximo relativo a la pantalla (estilo WhatsApp: ~78% del ancho
    // disponible), con un piso y un techo para que no se vea ni demasiado
    // angosta en pantallas chicas ni ridículamente ancha en tablets. El
    // ancho mínimo lo sigue definiendo el propio contenido (Column con
    // mainAxisSize.min más abajo), así que un "Hola" ocupa poco y un
    // mensaje largo ocupa hasta este máximo antes de saltar de línea.
    final screenWidth = MediaQuery.sizeOf(context).width;
    final maxBubbleWidth = (screenWidth * 0.78).clamp(220.0, 420.0);

    final bubble = Container(
      constraints: BoxConstraints(maxWidth: maxBubbleWidth),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: isMe ? null : AppColors.surface,
        gradient: isMe ? AppColors.buttonGradient : null,
        borderRadius: borderRadius,
        border: isMe ? null : Border.all(color: AppColors.surfaceBorder),
        boxShadow: [
          BoxShadow(
            color: (isMe ? AppColors.brandBlue : Colors.black).withValues(alpha: isMe ? 0.25 : 0.18),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                name,
                style: TextStyle(
                  color: IdentityAvatar.colorForId(username),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          if (replyTo != null)
            Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: isMe ? Colors.white.withValues(alpha: 0.15) : AppColors.bgBase,
                borderRadius: BorderRadius.circular(8),
                border: Border(
                  left: BorderSide(color: isMe ? AppColors.onBrand : AppColors.accent, width: 3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    replyTo!['name'] ?? '',
                    style: TextStyle(
                      color: isMe ? AppColors.onBrand : AppColors.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    replyTo!['message'] ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isMe ? AppColors.onBrandMuted : AppColors.textMuted,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
          Text(
            message,
            // La burbuja propia ("isMe") siempre tiene fondo azul
            // (buttonGradient), sin importar el modo: el texto debe quedar
            // fijo en blanco ahí; solo la burbuja ajena (fondo de superficie,
            // que sí cambia con el modo) usa el color dinámico.
            style: TextStyle(
              color: isMe ? AppColors.onBrand : AppColors.textPrimary,
              fontSize: 14,
              height: 1.3,
            ),
          ),
          if (showFooter)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Align(
                alignment: Alignment.centerRight,
                child: _MessageFooter(
                  time: time,
                  isMe: isMe,
                  status: isMe ? status : null,
                  onRetry: onRetry,
                ),
              ),
            ),
        ],
      ),
    );

    return GestureDetector(
      // Presión larga para elegir "responder" a este mensaje puntual,
      // igual que en WhatsApp/Slack. Si no se pasó [onReply], no hace nada.
      onLongPress: onReply,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: AppSpacing.lg),
        child: Row(
          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe) ...[
              IdentityAvatar(id: username, radius: 14, photoUrl: photoUrl),
              const SizedBox(width: AppSpacing.sm),
            ],
            Flexible(child: bubble),
          ],
        ),
      ),
    );
  }
}

/// Hora + indicador de estado, en la esquina inferior derecha de la
/// burbuja. Si el estado es [MessageStatus.failed], todo el footer se
/// vuelve tocable para reintentar el envío.
class _MessageFooter extends StatelessWidget {
  const _MessageFooter({
    required this.time,
    required this.isMe,
    required this.status,
    required this.onRetry,
  });

  final String? time;
  final bool isMe;
  final MessageStatus? status;
  final VoidCallback? onRetry;

  // Igual que el texto del mensaje: la burbuja "isMe" siempre es azul, así
  // que la hora sobre ella queda fija en blanco (con menor opacidad para
  // diferenciarla), no en el color dinámico que se oscurece en modo claro.
  Color _timeColor() => isMe ? AppColors.onBrandMuted : AppColors.textMuted;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (status == MessageStatus.failed) ...[
          Icon(Icons.error_outline, size: 13, color: AppColors.error),
          const SizedBox(width: 3),
          Text(
            'No entregado · reintentar',
            style: TextStyle(color: AppColors.error, fontSize: 10.5, fontWeight: FontWeight.w600),
          ),
        ] else ...[
          if (time != null && time!.isNotEmpty)
            Text(
              time!,
              style: TextStyle(color: _timeColor(), fontSize: 10.5, fontWeight: FontWeight.w500),
            ),
          if (status != null) ...[
            const SizedBox(width: 3),
            _StatusIcon(status: status!),
          ],
        ],
      ],
    );

    if (status == MessageStatus.failed && onRetry != null) {
      return InkWell(
        onTap: onRetry,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        child: Padding(padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2), child: row),
      );
    }
    return row;
  }
}

/// El ícono en sí (reloj / reintentando / un check / doble check gris o
/// azul), sin la parte de la hora.
class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status});

  final MessageStatus status;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      // Este ícono solo se dibuja en mensajes propios (isMe), es decir
      // siempre sobre la burbuja azul fija: por eso usa onBrand* en vez de
      // textMuted/accentStrong (que se oscurecen en modo claro y se pierden
      // contra el azul).
      case MessageStatus.sending:
        return Tooltip(
          message: 'Enviando…',
          child: Icon(Icons.schedule, size: 12, color: AppColors.onBrandMuted),
        );
      case MessageStatus.retrying:
        return Tooltip(
          message: 'Reintentando…',
          child: Icon(Icons.sync, size: 12, color: AppColors.warning),
        );
      case MessageStatus.failed:
        // Se dibuja aparte, en _MessageFooter (junto con el texto "No
        // entregado"), así que aquí no debería llegar a pintarse nada.
        return const SizedBox.shrink();
      case MessageStatus.sent:
        return Tooltip(
          message: 'Enviado',
          child: Icon(Icons.done, size: 14, color: AppColors.onBrandMuted),
        );
      case MessageStatus.delivered:
        return Tooltip(
          message: 'Entregado',
          child: Icon(Icons.done_all, size: 14, color: AppColors.onBrandMuted),
        );
      case MessageStatus.read:
        return Tooltip(
          message: 'Leído',
          child: Icon(Icons.done_all, size: 14, color: AppColors.onBrandAccent),
        );
    }
  }
}