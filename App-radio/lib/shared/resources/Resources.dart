import 'package:doliv_social/shared/resources/leader_assist.dart';
import 'package:doliv_social/shared/resources/doc.dart';
import 'package:doliv_social/shared/resources/fetch_r.dart';
import 'package:doliv_social/shared/resources/get_r.dart';
import 'package:doliv_social/shared/resources/imagecc.dart';
import 'package:doliv_social/shared/resources/team_documents_screen.dart';
import 'package:flutter/material.dart';
import 'package:doliv_social/design/design.dart';

/// Punto de entrada de "Recursos" de un equipo: accesos a documentación,
/// texto/imágenes publicados, publicar nuevos recursos, asistencia del líder
/// e imágenes del equipo — cada uno como una tarjeta con ícono y descripción,
/// igual que el resto de los "hub" de la app (ver `SiteContentHubScreen`).
class ResourceM extends StatelessWidget {
  final String teamId;
  const ResourceM(this.teamId, {super.key});

  List<_ResourceSection> get _sections => [
        _ResourceSection(
          icon: Icons.book_outlined,
          label: 'Documentación',
          description: 'Notas y avances guardados en este dispositivo.',
          builder: (context) => DocumentationPage(),
        ),
        _ResourceSection(
          icon: Icons.folder_outlined,
          label: 'Documentos',
          description:
              'Sube y descarga archivos (PDF, Word, Excel…) del equipo.',
          builder: (context) => TeamDocumentsScreen(teamId),
        ),
        _ResourceSection(
          icon: Icons.download_outlined,
          label: 'Ver recursos publicados',
          description: 'Textos e imágenes que ya compartió el equipo.',
          builder: (context) => ShowTextScreen(teamId),
        ),
        _ResourceSection(
          icon: Icons.post_add_outlined,
          label: 'Publicar recursos',
          description: 'Comparte un texto o una imagen con el equipo.',
          builder: (context) => PostTextScreen(teamId),
        ),
        _ResourceSection(
          icon: Icons.support_agent_outlined,
          label: 'Asistencia del líder',
          description: 'Envía un mensaje directo a tu líder de equipo.',
          builder: (context) => LeaderResource(teamId),
        ),
        _ResourceSection(
          icon: Icons.image_outlined,
          label: 'Imágenes del equipo',
          description: 'Galería de imágenes publicadas para este equipo.',
          builder: (context) => ImageListScreen(teamId),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        title: const Text('Recursos del equipo'),
        automaticallyImplyLeading: false,
      ),
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.lg),
          ResponsiveCardGrid(
            children: [
              for (final section in _sections)
                _SectionCard(
                  section: section,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: section.builder),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.section, required this.onTap});

  final _ResourceSection section;
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
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  section.description,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Icon(Icons.chevron_right, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

class _ResourceSection {
  _ResourceSection({
    required this.icon,
    required this.label,
    required this.description,
    required this.builder,
  });

  final IconData icon;
  final String label;
  final String description;
  final WidgetBuilder builder;
}
