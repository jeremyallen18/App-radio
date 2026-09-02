import 'package:brl_task4/ResourceM/Leaderassist.dart';
import 'package:brl_task4/ResourceM/doc.dart';
import 'package:brl_task4/ResourceM/documents.dart';
import 'package:brl_task4/ResourceM/fetchR.dart';
import 'package:brl_task4/ResourceM/getR.dart';
import 'package:brl_task4/ResourceM/imagecc.dart';
import 'package:flutter/material.dart';
import '../design/design.dart';

/// Pantalla "Resource Manager": menú de accesos a documentación, descarga
/// y publicación de recursos, asistencia para líderes e imágenes del
/// equipo. Migrada al sistema de diseño (`AppScaffold`/`AppCard`/tokens)
/// para que cada botón muestre, además del ícono, una descripción corta
/// de lo que hace — antes eran solo tiles cuadrados con un ícono y un
/// título.
class ResourceM extends StatelessWidget {
  final String teamId;
  ResourceM(this.teamId, {super.key});

  @override
  Widget build(BuildContext context) {
    final actions = _buildActions(teamId);

    return AppScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
              ),
              Expanded(
                child: Text(
                  'Resource Manager',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.only(left: 56, right: AppSpacing.lg, top: 4),
            child: Text(
              'Elige qué quieres hacer con los recursos de este equipo.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.only(bottom: AppSpacing.xl),
              itemCount: actions.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, index) => actions[index],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildActions(String teamId) {
    return [
      _ResourceActionCard(
        title: 'Documentación',
        description: 'Consulta guías y documentos de referencia del equipo.',
        icon: Icons.menu_book_rounded,
        color: AppColors.accent,
        destination: DocumentationPage(),
      ),
      _ResourceActionCard(
        title: 'Documentos',
        description: 'Sube y descarga archivos del equipo: PDF, Word, Excel y más.',
        icon: Icons.folder_shared_rounded,
        color: AppColors.accentStrong,
        destination: DocumentsScreen(teamId),
      ),
      _ResourceActionCard(
        title: 'Descargar recursos',
        description: 'Revisa y descarga los recursos que el equipo ya compartió.',
        icon: Icons.download_rounded,
        color: AppColors.success,
        destination: ShowTextScreen(teamId),
      ),
      _ResourceActionCard(
        title: 'Publicar recursos',
        description: 'Sube o redacta un nuevo recurso para que el equipo lo vea.',
        icon: Icons.note_add_rounded,
        color: AppColors.warning,
        destination: PostTextScreen(teamId),
      ),
      _ResourceActionCard(
        title: 'Asistencia para admins',
        description: 'Herramientas de apoyo pensadas para quien administra el equipo.',
        icon: Icons.support_agent_rounded,
        color: AppColors.error,
        destination: LeaderResource(teamId),
      ),
      _ResourceActionCard(
        title: 'Recursos de imágenes',
        description: 'Explora, sube y organiza las imágenes del equipo.',
        icon: Icons.image_rounded,
        color: Colors.purpleAccent,
        destination: ImageListScreen(teamId),
      ),
    ];
  }
}

/// Tarjeta de acción del Resource Manager: ícono en badge de color, título,
/// descripción de la función y chevron. Reemplaza a los antiguos tiles de
/// `GridView` (solo ícono + título, sin explicar qué hacía cada botón).
class _ResourceActionCard extends StatelessWidget {
  const _ResourceActionCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.destination,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final Widget destination;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => destination),
        );
      },
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ],
      ),
    );
  }
}