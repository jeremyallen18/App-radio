import 'package:flutter/material.dart';

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/models/internal_announcement.dart';
import 'package:doliv_social/services/internal_announcement_service.dart';

/// Historial de visualizaciones y confirmaciones de un anuncio interno
/// (solo director). Una fila por persona de la audiencia: si abrió el
/// anuncio y, cuando aplica, qué confirmó.
class InternalAnnouncementViewsScreen extends StatefulWidget {
  const InternalAnnouncementViewsScreen({
    super.key,
    required this.announcementId,
    required this.announcementTitle,
  });

  final String announcementId;
  final String announcementTitle;

  @override
  State<InternalAnnouncementViewsScreen> createState() =>
      _InternalAnnouncementViewsScreenState();
}

class _InternalAnnouncementViewsScreenState
    extends State<InternalAnnouncementViewsScreen> {
  late Future<AnnouncementViewsReport> _future;

  @override
  void initState() {
    super.initState();
    _future = InternalAnnouncementApi.views(widget.announcementId);
  }

  Future<void> _reload() async {
    final f = InternalAnnouncementApi.views(widget.announcementId);
    // Cuerpo con bloque: `=> _future = f` devuelve el Future asignado y
    // `setState` lo rechaza ("asynchronous work inside setState()").
    setState(() {
      _future = f;
    });
    await f;
  }

  String _fmt(DateTime d) {
    final local = d.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      padding: EdgeInsets.zero,
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Visualizaciones'),
      ),
      body: FutureBuilder<AnnouncementViewsReport>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingState(message: 'Cargando el historial...');
          }
          if (snapshot.hasError) {
            return ErrorState(
              message: snapshot.error.toString(),
              onRetry: _reload,
            );
          }
          final report = snapshot.data!;
          final viewers = report.viewers;

          return RefreshIndicator(
            color: AppColors.accent,
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.xxl,
              ),
              children: [
                Text(
                  widget.announcementTitle,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: StatTile(
                        icon: Icons.visibility_outlined,
                        value: '${report.viewCount}/${report.audienceCount}',
                        label: 'Han visto',
                        accentColor: AppColors.accent,
                      ),
                    ),
                    if (report.requiresConfirmation) ...[
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: StatTile(
                          icon: Icons.how_to_reg_outlined,
                          value: '${report.confirmedYes}',
                          label: 'Asistirán',
                          accentColor: AppColors.success,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: StatTile(
                          icon: Icons.cancel_outlined,
                          value: '${report.confirmedNo}',
                          label: 'No asistirán',
                          accentColor: AppColors.warning,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                const SectionHeader(title: 'Personas'),
                if (viewers.isEmpty)
                  const EmptyState(
                    icon: Icons.groups_outlined,
                    title: 'Sin audiencia',
                    message: 'Este anuncio no tiene destinatarios todavía.',
                  )
                else
                  for (final v in viewers) ...[
                    _ViewerTile(viewer: v, formatted: _fmt),
                    const SizedBox(height: AppSpacing.sm),
                  ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ViewerTile extends StatelessWidget {
  const _ViewerTile({required this.viewer, required this.formatted});

  final AnnouncementViewer viewer;
  final String Function(DateTime) formatted;

  @override
  Widget build(BuildContext context) {
    final confirmation = viewer.confirmation;
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            viewer.hasViewed ? Icons.visibility : Icons.visibility_off_outlined,
            color: viewer.hasViewed ? AppColors.success : AppColors.textMuted,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  viewer.name,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                if ((viewer.departmentName ?? '').isNotEmpty)
                  Text(
                    viewer.departmentName!,
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                const SizedBox(height: 4),
                Text(
                  viewer.viewedAt != null
                      ? 'Visto el ${formatted(viewer.viewedAt!)}'
                      : 'Todavía no lo ha visto',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          if (confirmation != null) ...[
            const SizedBox(width: AppSpacing.sm),
            AppBadge(
              label: confirmation == 'si' ? 'Asistirá' : 'No asistirá',
              variant: confirmation == 'si'
                  ? AppBadgeVariant.success
                  : AppBadgeVariant.warning,
            ),
          ],
        ],
      ),
    );
  }
}
