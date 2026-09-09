import 'package:flutter/material.dart';
import 'package:doliv_social/design/tokens/colors.dart';
import 'package:doliv_social/design/tokens/spacing.dart';

/// Barra de entrada de mensaje: campo tipo píldora + botón de enviar
/// circular. Pensado para chat, pero reutilizable en cualquier pantalla de
/// mensajería directa (p. ej. asistencia al líder).
class MessageComposer extends StatelessWidget {
  const MessageComposer({
    super.key,
    required this.controller,
    required this.onSend,
    this.hintText = 'Escribe un mensaje…',
    this.onToggleEmoji,
    this.emojiActive = false,
    this.focusNode,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final String hintText;

  /// Nodo de foco del campo. La pantalla lo controla para poder cerrar el
  /// teclado del sistema cuando abre su propio panel de emojis (y así no
  /// quedan dos teclados de emojis abiertos a la vez).
  final FocusNode? focusNode;

  /// Si se pasa, muestra un botón de emojis a la izquierda del campo. El
  /// selector de emojis vive en la pantalla que usa el composer (no aquí),
  /// para no acoplar este widget a un panel concreto.
  final VoidCallback? onToggleEmoji;

  /// Estado visual del botón de emojis (abierto / cerrado).
  final bool emojiActive;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (onToggleEmoji != null) ...[
              IconButton(
                onPressed: onToggleEmoji,
                visualDensity: VisualDensity.compact,
                tooltip: emojiActive ? 'Cerrar emojis' : 'Emojis',
                icon: Icon(
                  emojiActive
                      ? Icons.keyboard_outlined
                      : Icons.emoji_emotions_outlined,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 120),
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(color: AppColors.surfaceBorder),
                ),
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
                  cursorColor: AppColors.textPrimary,
                  onSubmitted: (_) => onSend(),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    hintText: hintText,
                    hintStyle:
                        TextStyle(color: AppColors.textMuted, fontSize: 14),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Material(
              color: AppColors.brandBlue,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onSend,
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Icon(Icons.send_rounded,
                      color: AppColors.textPrimary, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
