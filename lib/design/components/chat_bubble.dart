import 'package:flutter/material.dart';
import 'identity_avatar.dart';
import '../tokens/colors.dart';
import '../tokens/spacing.dart';

/// Burbuja de mensaje de chat, estilo Slack/Discord: avatar + nombre para
/// los mensajes de otras personas, alineado a la izquierda; los propios,
/// alineados a la derecha, sin avatar repetido.
///
/// El backend (`GET /chat/getAllChats`) no devuelve marca de tiempo hoy
/// (la columna `created_at` existe en la tabla pero el SELECT no la pide) —
/// este widget no muestra ninguna hora para no inventarla.
class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.username,
    required this.message,
    required this.isMe,
  });

  final String username;
  final String message;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isMe ? AppColors.brandBlue : AppColors.surface;
    final displayName = username.contains('@') ? username.substring(0, username.indexOf('@')) : username;

    final bubble = Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(AppRadius.card),
          topRight: const Radius.circular(AppRadius.card),
          bottomLeft: Radius.circular(isMe ? AppRadius.card : 4),
          bottomRight: Radius.circular(isMe ? 4 : AppRadius.card),
        ),
        border: isMe ? null : Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                displayName,
                style: TextStyle(color: IdentityAvatar.colorForId(username), fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
          Text(message, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: AppSpacing.lg),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            IdentityAvatar(id: username, radius: 14),
            const SizedBox(width: AppSpacing.sm),
          ],
          Flexible(child: bubble),
        ],
      ),
    );
  }
}
