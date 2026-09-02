import 'package:flutter/material.dart';
import '../tokens/colors.dart';
import '../tokens/spacing.dart';
import 'emoji_picker_panel.dart';

/// Barra de entrada de mensaje: botón de emoji + campo tipo píldora +
/// botón de enviar circular con degradado de marca. Pensado para chat,
/// pero reutilizable en cualquier pantalla de mensajería directa (p. ej.
/// asistencia al líder).
///
/// El selector de emojis (ver [EmojiPickerPanel]) se abre/cierra tocando
/// el botón de la izquierda, igual que en WhatsApp: al abrirlo se oculta
/// el teclado nativo para no tener los dos a la vez.
class MessageComposer extends StatefulWidget {
  const MessageComposer({
    super.key,
    required this.controller,
    required this.onSend,
    this.hintText = 'Escribe un mensaje…',
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final String hintText;

  @override
  State<MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends State<MessageComposer> {
  final FocusNode _focusNode = FocusNode();
  bool _showEmojiPicker = false;

  void _toggleEmojiPicker() {
    if (_showEmojiPicker) {
      setState(() => _showEmojiPicker = false);
      _focusNode.requestFocus();
      return;
    }
    // Oculta el teclado nativo antes de mostrar el panel de emojis, para
    // que no compitan por el mismo espacio en pantalla.
    _focusNode.unfocus();
    setState(() => _showEmojiPicker = true);
  }

  void _insertEmoji(String emoji) {
    final controller = widget.controller;
    final selection = controller.selection;
    final text = controller.text;
    if (!selection.isValid || selection.start < 0) {
      controller.text = text + emoji;
      controller.selection = TextSelection.collapsed(offset: controller.text.length);
      return;
    }
    final newText = text.replaceRange(selection.start, selection.end, emoji);
    controller.text = newText;
    controller.selection = TextSelection.collapsed(offset: selection.start + emoji.length);
  }

  void _handleSend() {
    setState(() => _showEmojiPicker = false);
    widget.onSend();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.bgBase,
        border: Border(top: BorderSide(color: AppColors.surfaceBorder)),
      ),
      child: SafeArea(
        top: false,
        // Cuando el panel de emojis está abierto no hace falta respetar
        // el gap inferior del sistema (el panel ya trae su propia altura
        // fija), así que solo se aplica al cerrarlo.
        bottom: !_showEmojiPicker,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: _showEmojiPicker ? 'Ocultar emojis' : 'Insertar emoji',
                    icon: Icon(
                      _showEmojiPicker ? Icons.keyboard_alt_outlined : Icons.emoji_emotions_outlined,
                      color: AppColors.textMuted,
                    ),
                    onPressed: _toggleEmojiPicker,
                  ),
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 120),
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(color: AppColors.surfaceBorder),
                      ),
                      child: TextField(
                        controller: widget.controller,
                        focusNode: _focusNode,
                        minLines: 1,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
                        cursorColor: AppColors.accent,
                        onTap: () {
                          // Si el usuario toca el campo de texto con el
                          // panel de emojis abierto, se cierra para dar
                          // paso al teclado (igual que en WhatsApp).
                          if (_showEmojiPicker) {
                            setState(() => _showEmojiPicker = false);
                          }
                        },
                        onSubmitted: (_) => _handleSend(),
                        decoration: InputDecoration(
                          isCollapsed: true,
                          border: InputBorder.none,
                          hintText: widget.hintText,
                          hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.buttonGradient,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.brandBlue.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _handleSend,
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: Icon(Icons.send_rounded, color: AppColors.textPrimary, size: 20),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_showEmojiPicker)
              EmojiPickerPanel(
                onEmojiSelected: (emoji) {
                  _insertEmoji(emoji);
                  // No se cierra el panel al elegir un emoji: así se
                  // pueden encadenar varios seguidos, igual que WhatsApp.
                  setState(() {});
                },
              ),
          ],
        ),
      ),
    );
  }
}
