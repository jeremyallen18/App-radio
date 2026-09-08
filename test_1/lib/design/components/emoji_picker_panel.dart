import 'package:flutter/material.dart';
import '../tokens/colors.dart';
import '../tokens/spacing.dart';
import 'emoji_catalog.dart';

/// Panel de selección de emojis al estilo WhatsApp: categorías en pestañas.
/// Se usa dentro de [MessageComposer], que lo muestra/oculta al tocar el
/// botón de emoji.
///
/// No tiene buscador de texto a propósito: cualquier campo de texto abriría
/// el teclado del sistema (con su propia rejilla de emojis) encima de este
/// panel, y quedarían dos teclados de emojis a la vez. Aquí solo se navega
/// por categorías, así que el panel nunca necesita el teclado del sistema.
///
/// No depende de ningún paquete externo de emoji: usa caracteres Unicode
/// directamente, así que solo hace falta que la fuente del sistema los
/// sepa dibujar (igual que cualquier teclado emoji nativo).
class EmojiPickerPanel extends StatefulWidget {
  const EmojiPickerPanel({super.key, required this.onEmojiSelected});

  final ValueChanged<String> onEmojiSelected;

  static const double height = 260;

  @override
  State<EmojiPickerPanel> createState() => _EmojiPickerPanelState();
}

class _EmojiPickerPanelState extends State<EmojiPickerPanel>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: emojiCatalog.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _grid(List<EmojiEntry> entries) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 8,
      ),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: () => widget.onEmojiSelected(entry.char),
          child: Center(
            child: Text(entry.char, style: const TextStyle(fontSize: 22)),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: EmojiPickerPanel.height,
      decoration: BoxDecoration(
        color: AppColors.bgBase,
        border: Border(top: BorderSide(color: AppColors.surfaceBorder)),
      ),
      child: Column(
        children: [
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: AppColors.accent,
            labelColor: AppColors.accent,
            unselectedLabelColor: AppColors.textMuted,
            tabs: [
              for (final c in emojiCatalog)
                Tab(icon: Icon(c.icon, size: 18), text: c.label),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [for (final c in emojiCatalog) _grid(c.entries)],
            ),
          ),
        ],
      ),
    );
  }
}
