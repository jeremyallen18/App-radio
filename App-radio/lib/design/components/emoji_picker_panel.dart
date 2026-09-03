import 'package:flutter/material.dart';
import '../tokens/colors.dart';
import '../tokens/spacing.dart';
import 'emoji_catalog.dart';

/// Panel de selección de emojis al estilo WhatsApp: categorías en
/// pestañas + buscador. Se usa dentro de [MessageComposer], que lo
/// muestra/oculta al tocar el botón de emoji.
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
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: emojiCatalog.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<EmojiEntry> get _searchResults {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return emojiCatalog
        .expand((c) => c.entries)
        .where((e) => e.keywords.contains(q) || e.char == q)
        .toList();
  }

  Widget _grid(List<EmojiEntry> entries) {
    if (entries.isEmpty) {
      return Center(
        child: Text(
          'Sin resultados',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
      );
    }
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
    final searching = _query.trim().isNotEmpty;

    return Container(
      height: EmojiPickerPanel.height,
      decoration: BoxDecoration(
        color: AppColors.bgBase,
        border: Border(top: BorderSide(color: AppColors.surfaceBorder)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: Row(
                children: [
                  Icon(Icons.search, size: 18, color: AppColors.textMuted),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _query = v),
                      style:
                          TextStyle(color: AppColors.textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        isCollapsed: true,
                        border: InputBorder.none,
                        hintText: 'Buscar emoji…',
                        hintStyle:
                            TextStyle(color: AppColors.textMuted, fontSize: 13),
                      ),
                    ),
                  ),
                  if (searching)
                    InkWell(
                      onTap: () => setState(() {
                        _query = '';
                        _searchController.clear();
                      }),
                      child: Icon(Icons.close,
                          size: 16, color: AppColors.textMuted),
                    ),
                ],
              ),
            ),
          ),
          if (!searching)
            TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: AppColors.accent,
              labelColor: AppColors.accent,
              unselectedLabelColor: AppColors.textMuted,
              tabs: [
                for (final c in emojiCatalog)
                  Tab(icon: Icon(c.icon, size: 18), text: c.label),
              ],
            ),
          Expanded(
            child: searching
                ? _grid(_searchResults)
                : TabBarView(
                    controller: _tabController,
                    children: [for (final c in emojiCatalog) _grid(c.entries)],
                  ),
          ),
        ],
      ),
    );
  }
}
