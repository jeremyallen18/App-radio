import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:doliv_social/core/api_config.dart';
import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/features/dashboard/director/site_content/anuncio_form.dart';
import 'package:doliv_social/features/dashboard/director/site_content/equipo_form.dart';
import 'package:doliv_social/features/dashboard/director/site_content/evento_form.dart';
import 'package:doliv_social/features/dashboard/director/site_content/patrocinador_form.dart';
import 'package:doliv_social/features/dashboard/director/site_content/podcast_form.dart';
import 'package:doliv_social/features/dashboard/director/site_content/programa_form.dart';
import 'package:doliv_social/features/dashboard/director/site_content/servicio_form.dart';
import 'package:doliv_social/features/dashboard/director/site_content/site_content_api.dart';
import 'package:doliv_social/features/dashboard/director/site_content/site_content_list_screen.dart';

/// Punto de entrada de "Contenido del sitio web". Agrupa las siete áreas del
/// sitio y ofrece un vistazo del contenido publicado antes de abrir cada una.
class SiteContentHubScreen extends StatefulWidget {
  const SiteContentHubScreen({super.key});

  @override
  State<SiteContentHubScreen> createState() => _SiteContentHubScreenState();
}

class _SiteContentHubScreenState extends State<SiteContentHubScreen> {
  late final List<_HubCategory> _categories = [
    _HubCategory(
      title: 'Contenido editorial',
      sections: [
        _HubSection(
          icon: Icons.campaign_outlined,
          iconColor: const Color(0xFF60A5FA),
          label: 'Anuncios',
          description: 'Avisos y novedades destacadas en la página principal.',
          resource: 'anuncios',
          itemTitle: (item) => item['titulo']?.toString() ?? '',
          itemSubtitle: (item) => item['fecha_publicacion']?.toString() ?? '',
          builder: (context) => SiteContentListScreen(
            title: 'Anuncios',
            resource: 'anuncios',
            itemTitle: (item) => item['titulo']?.toString() ?? '',
            itemSubtitle: (item) => item['fecha_publicacion']?.toString(),
            itemImage: (item) => item['imagen_url']?.toString(),
            formBuilder: (context, item) => AnuncioFormScreen(item: item),
          ),
        ),
        _HubSection(
          icon: Icons.event_outlined,
          iconColor: const Color(0xFF38BDF8),
          label: 'Eventos',
          description: 'Actividades y fechas próximas de la emisora.',
          resource: 'eventos',
          itemTitle: (item) => item['title']?.toString() ?? '',
          itemSubtitle: (item) => item['location']?.toString() ?? '',
          builder: (context) => SiteContentListScreen(
            title: 'Eventos',
            resource: 'eventos',
            itemTitle: (item) => item['title']?.toString() ?? '',
            itemSubtitle: (item) => item['location']?.toString(),
            itemImage: (item) => item['image']?.toString(),
            formBuilder: (context, item) => EventoFormScreen(item: item),
          ),
        ),
      ],
    ),
    _HubCategory(
      title: 'Programación al aire',
      sections: [
        _HubSection(
          icon: Icons.radio_outlined,
          iconColor: const Color(0xFF818CF8),
          label: 'Programas al aire',
          description: 'Parrilla de programas y sus horarios de transmisión.',
          resource: 'programas',
          itemTitle: (item) => item['title']?.toString() ?? '',
          itemSubtitle: (item) => item['schedule']?.toString() ?? '',
          builder: (context) => SiteContentListScreen(
            title: 'Programas al aire',
            resource: 'programas',
            itemTitle: (item) => item['title']?.toString() ?? '',
            itemSubtitle: (item) => item['schedule']?.toString(),
            itemImage: (item) => item['image']?.toString(),
            formBuilder: (context, item) => ProgramaFormScreen(item: item),
          ),
        ),
        _HubSection(
          icon: Icons.podcasts_outlined,
          iconColor: const Color(0xFFC084FC),
          label: 'Podcasts',
          description: 'Episodios disponibles para escuchar bajo demanda.',
          resource: 'podcasts',
          itemTitle: (item) => item['title']?.toString() ?? '',
          itemSubtitle: (item) =>
              '${(item['episodes'] as List?)?.length ?? 0} episodios',
          builder: (context) => SiteContentListScreen(
            title: 'Podcasts',
            resource: 'podcasts',
            itemTitle: (item) => item['title']?.toString() ?? '',
            itemSubtitle: (item) =>
                '${(item['episodes'] as List?)?.length ?? 0} episodios',
            itemImage: (item) => item['cover']?.toString(),
            formBuilder: (context, item) => PodcastFormScreen(item: item),
          ),
        ),
      ],
    ),
    _HubCategory(
      title: 'Comunidad y alianzas',
      sections: [
        _HubSection(
          icon: Icons.groups_outlined,
          iconColor: const Color(0xFF2DD4BF),
          label: 'Equipo',
          description:
              'Locutores y staff que aparecen en la página del equipo.',
          resource: 'equipo',
          itemTitle: (item) => item['name']?.toString() ?? '',
          itemSubtitle: (item) => item['role']?.toString() ?? '',
          builder: (context) => SiteContentListScreen(
            title: 'Equipo',
            resource: 'equipo',
            itemTitle: (item) => item['name']?.toString() ?? '',
            itemSubtitle: (item) => item['role']?.toString(),
            itemImage: (item) => item['image']?.toString(),
            formBuilder: (context, item) => EquipoFormScreen(item: item),
          ),
        ),
        _HubSection(
          icon: Icons.business_center_outlined,
          iconColor: const Color(0xFF60A5FA),
          label: 'Servicios',
          description: 'Servicios que la emisora ofrece a sus clientes.',
          resource: 'servicios',
          itemTitle: (item) => item['title']?.toString() ?? '',
          itemSubtitle: (item) => item['category']?.toString() ?? '',
          builder: (context) => SiteContentListScreen(
            title: 'Servicios',
            resource: 'servicios',
            itemTitle: (item) => item['title']?.toString() ?? '',
            itemSubtitle: (item) => item['category']?.toString(),
            itemImage: (item) => item['image']?.toString(),
            formBuilder: (context, item) => ServicioFormScreen(item: item),
          ),
        ),
        _HubSection(
          icon: Icons.storefront_outlined,
          iconColor: const Color(0xFF60A5FA),
          label: 'Sección Azul\n(patrocinadores)',
          description:
              'Marcas y aliados comerciales que patrocinan la emisora.',
          resource: 'patrocinadores',
          itemTitle: (item) => item['name']?.toString() ?? '',
          itemSubtitle: (item) => item['category_label']?.toString() ?? '',
          builder: (context) => SiteContentListScreen(
            title: 'Sección Azul',
            resource: 'patrocinadores',
            itemTitle: (item) => item['name']?.toString() ?? '',
            itemSubtitle: (item) => item['category_label']?.toString(),
            itemImage: (item) => item['image']?.toString(),
            formBuilder: (context, item) => PatrocinadorFormScreen(item: item),
          ),
        ),
      ],
    ),
  ];

  final Map<String, _SectionSummary> _summaries = {};

  @override
  void initState() {
    super.initState();
    _loadSummaries();
  }

  Future<void> _loadSummaries() async {
    final sections = _categories.expand((category) => category.sections);
    final entries = await Future.wait(sections.map((section) async {
      final items = await SiteContentApi(section.resource).list();
      return MapEntry(section.resource, _SectionSummary(items: items));
    }));
    if (!mounted) return;
    setState(() => _summaries
      ..clear()
      ..addEntries(entries));
  }

  Future<void> _openSection(_HubSection section) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: section.builder),
    );
    if (mounted) _loadSummaries();
  }

  Future<void> _addItem(_HubSection section) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (context) => section.builder(context)),
    );
    if (saved == true && mounted) _loadSummaries();
  }

  Future<void> _openLiveWebsite() async {
    final websiteUri = Uri.parse(kSiteBaseUrl);
    if (await launchUrl(websiteUri, mode: LaunchMode.externalApplication)) {
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No se pudo abrir el sitio web en vivo.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      padding: EdgeInsets.zero,
      body: RefreshIndicator(
        color: const Color(0xFF60A5FA),
        onRefresh: _loadSummaries,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 48),
          children: [
            _HubHeader(onBack: () => Navigator.of(context).maybePop()),
            const SizedBox(height: 28),
            _LiveNotice(onOpenLiveWebsite: _openLiveWebsite),
            const SizedBox(height: 22),
            for (final category in _categories) ...[
              _CategoryHeading(category.title),
              const SizedBox(height: 10),
              ResponsiveCardGrid(
                children: [
                  for (final section in category.sections)
                    _SectionCard(
                      section: section,
                      summary: _summaries[section.resource],
                      onTap: () => _openSection(section),
                      onQuickAdd: () => _addItem(section),
                    ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }
}

class _HubHeader extends StatelessWidget {
  const _HubHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          color: const Color(0xFFC7D2E5),
          visualDensity: VisualDensity.compact,
          tooltip: 'Volver',
        ),
        const SizedBox(width: 8),
        const Expanded(
          child: Text(
            'Contenido del sitio web',
            style: TextStyle(
              color: Color(0xFFF8FAFC),
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _LiveNotice extends StatelessWidget {
  const _LiveNotice({required this.onOpenLiveWebsite});

  final VoidCallback onOpenLiveWebsite;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpenLiveWebsite,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF251407),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF85410B)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.public, color: Color(0xFFFCD34D), size: 16),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Estos cambios se publican de inmediato en\nradiodoliv.com.',
                      style: TextStyle(
                        color: Color(0xFFFDE68A),
                        fontSize: 11,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 5),
                    Row(
                      children: [
                        Text(
                          'Ver web en vivo',
                          style: TextStyle(
                            color: Color(0xFFFCD34D),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(width: 3),
                        Icon(
                          Icons.open_in_new,
                          color: Color(0xFFFCD34D),
                          size: 13,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryHeading extends StatelessWidget {
  const _CategoryHeading(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFFF8FAFC),
        fontSize: 13,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.1,
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.section,
    required this.summary,
    required this.onTap,
    required this.onQuickAdd,
  });

  final _HubSection section;
  final _SectionSummary? summary;
  final VoidCallback onTap;
  final VoidCallback onQuickAdd;

  @override
  Widget build(BuildContext context) {
    final itemCount = summary?.items.length;
    // El API ya entrega los elementos en el mismo orden que se muestra en el
    // sitio público (fecha para anuncios; sort_order para las demás secciones).
    final primaryItem =
        itemCount == null || itemCount == 0 ? null : summary!.items.first;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          decoration: BoxDecoration(
            color: const Color(0xFF101C31),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF273753)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: section.iconColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: section.iconColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child:
                        Icon(section.icon, color: section.iconColor, size: 21),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            section.label,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFF8FAFC),
                              fontSize: 16,
                              height: 1.2,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            section.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF9FB3D1),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: onQuickAdd,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    color: const Color(0xFFB4C2D8),
                    tooltip: 'Añadir ${section.label}',
                    visualDensity: VisualDensity.compact,
                    constraints:
                        const BoxConstraints.tightFor(width: 28, height: 28),
                    padding: EdgeInsets.zero,
                    style: IconButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(7),
                        side: const BorderSide(color: Color(0xFF3A4A63)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFF71839F),
                      size: 22,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _PrimarySiteItem(
                  section: section,
                  item: primaryItem,
                  isLoading: itemCount == null),
              const SizedBox(height: 10),
              const Divider(height: 1, color: Color(0xFF273753)),
              const SizedBox(height: 10),
              _CardMetadata(itemCount: itemCount),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrimarySiteItem extends StatelessWidget {
  const _PrimarySiteItem({
    required this.section,
    required this.item,
    required this.isLoading,
  });

  final _HubSection section;
  final Map<String, dynamic>? item;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final title = item == null
        ? 'Aún no hay contenido publicado'
        : section.itemTitle(item!);
    final subtitle = item == null
        ? (isLoading
            ? 'Cargando contenido...'
            : 'Crea el primer elemento de esta sección')
        : section.itemSubtitle(item!);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF081326),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1D2D48)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PRIMERO EN EL SITIO',
            style: TextStyle(
              color: Color(0xFF7588A5),
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title.isEmpty ? 'Sin título' : title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFE2E8F0),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            subtitle.isEmpty ? 'Sin información adicional' : subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF9FB3D1), fontSize: 9),
          ),
        ],
      ),
    );
  }
}

class _CardMetadata extends StatelessWidget {
  const _CardMetadata({required this.itemCount});

  final int? itemCount;

  @override
  Widget build(BuildContext context) {
    if (itemCount == null) {
      return const Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(
          width: 13,
          height: 13,
          child: CircularProgressIndicator(
            color: Color(0xFF60A5FA),
            strokeWidth: 1.5,
          ),
        ),
      );
    }

    final label = itemCount == 1 ? '1 elemento' : '$itemCount elementos';
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFF0B2754),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0xFF1D4E9A)),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF60A5FA),
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 8),
        const Icon(Icons.check_circle_outline,
            color: Color(0xFF2DD4BF), size: 12),
        const SizedBox(width: 4),
        Text(
          '$itemCount publicados',
          style: const TextStyle(color: Color(0xFF9FB3D1), fontSize: 9),
        ),
        const Spacer(),
        const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Gestionar',
              style: TextStyle(
                color: Color(0xFFB4C2D8),
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(width: 2),
            Icon(
              Icons.arrow_forward,
              color: Color(0xFFB4C2D8),
              size: 12,
            ),
          ],
        ),
      ],
    );
  }
}

class _SectionSummary {
  const _SectionSummary({required this.items});

  final List<Map<String, dynamic>> items;
}

class _HubCategory {
  const _HubCategory({required this.title, required this.sections});

  final String title;
  final List<_HubSection> sections;
}

class _HubSection {
  const _HubSection({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.description,
    required this.resource,
    required this.itemTitle,
    required this.itemSubtitle,
    required this.builder,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String description;
  final String resource;
  final String Function(Map<String, dynamic> item) itemTitle;
  final String Function(Map<String, dynamic> item) itemSubtitle;
  final WidgetBuilder builder;
}
