import 'package:flutter/material.dart';

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

/// Punto de entrada de "Contenido del sitio web": las 7 secciones agrupadas
/// por tipo de contenido, cada una con una descripción de una línea y el
/// número de elementos publicados, para que el director sepa qué hay antes
/// de entrar. Cada tarjeta navega a su [SiteContentListScreen] configurada.
/// Exclusivo del director — se llega aquí desde `DirectorDashboard`, que ya
/// está protegido por `RoleDashboardRouter`.
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
          label: 'Anuncios',
          description: 'Avisos y novedades destacadas en la página principal.',
          resource: 'anuncios',
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
          label: 'Eventos',
          description: 'Actividades y fechas próximas de la emisora.',
          resource: 'eventos',
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
          label: 'Programas al aire',
          description: 'Parrilla de programas y sus horarios de transmisión.',
          resource: 'programas',
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
          label: 'Podcasts',
          description: 'Episodios disponibles para escuchar bajo demanda.',
          resource: 'podcasts',
          builder: (context) => SiteContentListScreen(
            title: 'Podcasts',
            resource: 'podcasts',
            itemTitle: (item) => item['title']?.toString() ?? '',
            itemSubtitle: (item) => '${(item['episodes'] as List?)?.length ?? 0} episodios',
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
          label: 'Equipo',
          description: 'Locutores y staff que aparecen en la página del equipo.',
          resource: 'equipo',
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
          icon: Icons.design_services_outlined,
          label: 'Servicios',
          description: 'Servicios que la emisora ofrece a sus clientes.',
          resource: 'servicios',
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
          label: 'Sección Azul (patrocinadores)',
          description: 'Marcas y aliados comerciales que patrocinan la emisora.',
          resource: 'patrocinadores',
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

  final Map<String, int?> _counts = {};

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    final sections = _categories.expand((c) => c.sections).toList();
    final entries = await Future.wait(sections.map((section) async {
      try {
        final items = await SiteContentApi(section.resource).list();
        return MapEntry(section.resource, items.length);
      } catch (_) {
        return MapEntry<String, int?>(section.resource, null);
      }
    }));
    if (!mounted) return;
    setState(() => _counts.addEntries(entries));
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      padding: EdgeInsets.zero,
      appBar: AppBar(title: const Text('Contenido del sitio web')),
      body: RefreshIndicator(
        onRefresh: _loadCounts,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.xxxl,
          ),
          children: [
            const Text(
              'Estos cambios se publican de inmediato en radiodoliv.com.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: AppSpacing.xl),
            for (final category in _categories) ...[
              SectionHeader(title: category.title),
              ResponsiveCardGrid(
                children: [
                  for (final section in category.sections)
                    _SectionCard(
                      section: section,
                      count: _counts[section.resource],
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: section.builder),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.section, required this.count, required this.onTap});

  final _HubSection section;
  final int? count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(section.icon, color: AppColors.accent, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  section.label,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  section.description,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
                const SizedBox(height: AppSpacing.sm),
                count == null
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.textMuted,
                        ),
                      )
                    : AppBadge(label: count == 1 ? '1 elemento' : '$count elementos'),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          const Icon(Icons.chevron_right, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

class _HubCategory {
  _HubCategory({required this.title, required this.sections});

  final String title;
  final List<_HubSection> sections;
}

class _HubSection {
  _HubSection({
    required this.icon,
    required this.label,
    required this.description,
    required this.resource,
    required this.builder,
  });

  final IconData icon;
  final String label;
  final String description;
  final String resource;
  final WidgetBuilder builder;
}
