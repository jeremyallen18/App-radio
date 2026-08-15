import 'package:flutter/material.dart';

import '../../design/design.dart';
import 'anuncio_form.dart';
import 'equipo_form.dart';
import 'evento_form.dart';
import 'patrocinador_form.dart';
import 'podcast_form.dart';
import 'programa_form.dart';
import 'servicio_form.dart';
import 'site_content_list_screen.dart';

/// Punto de entrada de "Contenido del sitio web": una tarjeta por recurso,
/// cada una navega a su [SiteContentListScreen] configurada. Exclusivo del
/// director — se llega aquí desde `DirectorDashboard`, que ya está
/// protegido por `RoleDashboardRouter`.
class SiteContentHubScreen extends StatelessWidget {
  const SiteContentHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sections = <_HubSection>[
      _HubSection(
        icon: Icons.campaign_outlined,
        label: 'Anuncios',
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
        builder: (context) => SiteContentListScreen(
          title: 'Eventos',
          resource: 'eventos',
          itemTitle: (item) => item['title']?.toString() ?? '',
          itemSubtitle: (item) => item['location']?.toString(),
          itemImage: (item) => item['image']?.toString(),
          formBuilder: (context, item) => EventoFormScreen(item: item),
        ),
      ),
      _HubSection(
        icon: Icons.storefront_outlined,
        label: 'Sección Azul (patrocinadores)',
        builder: (context) => SiteContentListScreen(
          title: 'Sección Azul',
          resource: 'patrocinadores',
          itemTitle: (item) => item['name']?.toString() ?? '',
          itemSubtitle: (item) => item['category_label']?.toString(),
          itemImage: (item) => item['image']?.toString(),
          formBuilder: (context, item) => PatrocinadorFormScreen(item: item),
        ),
      ),
      _HubSection(
        icon: Icons.podcasts_outlined,
        label: 'Podcasts',
        builder: (context) => SiteContentListScreen(
          title: 'Podcasts',
          resource: 'podcasts',
          itemTitle: (item) => item['title']?.toString() ?? '',
          itemSubtitle: (item) => '${(item['episodes'] as List?)?.length ?? 0} episodios',
          itemImage: (item) => item['cover']?.toString(),
          formBuilder: (context, item) => PodcastFormScreen(item: item),
        ),
      ),
      _HubSection(
        icon: Icons.design_services_outlined,
        label: 'Servicios',
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
        icon: Icons.groups_outlined,
        label: 'Equipo',
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
        icon: Icons.radio_outlined,
        label: 'Programas al aire',
        builder: (context) => SiteContentListScreen(
          title: 'Programas al aire',
          resource: 'programas',
          itemTitle: (item) => item['title']?.toString() ?? '',
          itemSubtitle: (item) => item['schedule']?.toString(),
          itemImage: (item) => item['image']?.toString(),
          formBuilder: (context, item) => ProgramaFormScreen(item: item),
        ),
      ),
    ];

    return AppScaffold(
      padding: EdgeInsets.zero,
      appBar: AppBar(title: const Text('Contenido del sitio web')),
      body: ListView(
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
          const SizedBox(height: AppSpacing.lg),
          for (final section in sections) ...[
            AppCard(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: section.builder),
              ),
              child: Row(
                children: [
                  Icon(section.icon, color: AppColors.accent),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      section.label,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.textMuted),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _HubSection {
  _HubSection({required this.icon, required this.label, required this.builder});

  final IconData icon;
  final String label;
  final WidgetBuilder builder;
}
