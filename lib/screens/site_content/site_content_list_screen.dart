import 'package:flutter/material.dart';

import '../../design/design.dart';
import 'site_content_api.dart';

/// Lista genérica para un recurso de contenido del sitio (anuncios,
/// eventos, patrocinadores, podcasts, servicios, equipo, programas): trae
/// los registros, los muestra con miniatura/título/subtítulo, y permite
/// crear/editar (navegando a [formBuilder]) o eliminar. Es el mismo
/// contenido en los 7 casos — solo cambia la configuración, así que se
/// evita repetir esta pantalla 7 veces.
class SiteContentListScreen extends StatefulWidget {
  const SiteContentListScreen({
    super.key,
    required this.title,
    required this.resource,
    required this.itemTitle,
    this.itemSubtitle,
    this.itemImage,
    required this.formBuilder,
  });

  final String title;
  final String resource;
  final String Function(Map<String, dynamic> item) itemTitle;
  final String? Function(Map<String, dynamic> item)? itemSubtitle;
  final String? Function(Map<String, dynamic> item)? itemImage;

  /// Construye la pantalla de formulario. `item == null` significa "crear
  /// nuevo"; si no, el mapa trae el registro a editar. Debe hacer `pop(true)`
  /// al guardar con éxito para que la lista se refresque.
  final Widget Function(BuildContext context, Map<String, dynamic>? item) formBuilder;

  @override
  State<SiteContentListScreen> createState() => _SiteContentListScreenState();
}

class _SiteContentListScreenState extends State<SiteContentListScreen> {
  late final SiteContentApi _api = SiteContentApi(widget.resource);
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _api.list();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openForm({Map<String, dynamic>? item}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (context) => widget.formBuilder(context, item)),
    );
    if (saved == true) _load();
  }

  Future<void> _confirmDelete(Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar este elemento?'),
        content: Text(widget.itemTitle(item)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _api.delete(item['id'].toString());
      if (!mounted) return;
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      padding: EdgeInsets.zero,
      appBar: AppBar(title: Text(widget.title)),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        backgroundColor: AppColors.brandBlue,
        child: const Icon(Icons.add, color: AppColors.textPrimary),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: Builder(
          builder: (context) {
            if (_loading) return const LoadingState();
            if (_error != null) {
              return ErrorState(message: _error!, onRetry: _load);
            }
            if (_items.isEmpty) {
              return const EmptyState(
                icon: Icons.web_asset_outlined,
                title: 'Todavía no hay elementos',
                message: 'Toca el botón + para crear el primero.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.xxxl,
              ),
              itemCount: _items.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final item = _items[index];
                final imageUrl = widget.itemImage != null
                    ? siteImageUrl(widget.itemImage!(item))
                    : null;
                final subtitle = widget.itemSubtitle?.call(item);
                return AppCard(
                  onTap: () => _openForm(item: item),
                  child: Row(
                    children: [
                      if (imageUrl != null) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.chip),
                          child: Image.network(
                            imageUrl,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const SizedBox(width: 48, height: 48),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.itemTitle(item),
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            if (subtitle != null && subtitle.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                subtitle,
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: AppColors.error),
                        onPressed: () => _confirmDelete(item),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
