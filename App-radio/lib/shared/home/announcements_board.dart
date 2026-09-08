import 'package:flutter/material.dart';

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/models/internal_announcement.dart';
import 'package:doliv_social/services/internal_announcement_service.dart';
import 'package:doliv_social/features/dashboard/director/internal_announcement_form.dart';
import 'package:doliv_social/features/dashboard/director/internal_announcement_views_screen.dart';

/// Cuerpo de la pantalla de inicio: el tablero de **anuncios internos** de la
/// empresa. Las secciones operativas (asistencia, calendario, tareas…) viven
/// en el menú hamburguesa ([AppMenuDrawer]).
///
/// - Director: botón para publicar, y la lista de todos los anuncios con
///   acciones de editar / eliminar / ver visualizaciones.
/// - Resto: los anuncios activos que le corresponden; si el anuncio lo pide
///   (una reunión), puede confirmar asistencia (sí / no).
class AnnouncementsBoard extends StatefulWidget {
  const AnnouncementsBoard({super.key});

  @override
  State<AnnouncementsBoard> createState() => _AnnouncementsBoardState();
}

class _AnnouncementsBoardState extends State<AnnouncementsBoard> {
  List<InternalAnnouncement> _items = const [];
  bool _canManage = false;
  bool _loading = true;
  String? _error;
  String? _busyId; // anuncio con una acción en curso

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
      final res = await InternalAnnouncementApi.list();
      if (!mounted) return;
      setState(() {
        _items = res.items;
        _canManage = res.canManage;
        _loading = false;
      });
    } on InternalAnnouncementException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _openForm({InternalAnnouncement? existing}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => InternalAnnouncementFormScreen(existing: existing),
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _delete(InternalAnnouncement a) async {
    final ok = await showAppConfirmDialog(
      context,
      title: 'Eliminar anuncio',
      message: '¿Eliminar "${a.title}"? Se perderá su historial de visualizaciones.',
      confirmLabel: 'Eliminar',
      danger: true,
    );
    if (ok != true) return;
    setState(() => _busyId = a.id);
    try {
      await InternalAnnouncementApi.delete(a.id);
      await _load();
    } on InternalAnnouncementException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  void _openViews(InternalAnnouncement a) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InternalAnnouncementViewsScreen(
          announcementId: a.id,
          announcementTitle: a.title,
        ),
      ),
    );
  }

  Future<void> _confirm(InternalAnnouncement a, {required bool attending}) async {
    setState(() => _busyId = a.id);
    try {
      final updated =
          await InternalAnnouncementApi.confirm(a.id, attending: attending);
      if (!mounted) return;
      setState(() {
        _items = [
          for (final x in _items) if (x.id == a.id) updated else x,
        ];
      });
    } on InternalAnnouncementException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingState();
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        children: [
          SectionHeader(
            title: 'Anuncios internos',
            action: _canManage
                ? TextButton.icon(
                    onPressed: () => _openForm(),
                    icon: const Icon(Icons.add),
                    label: const Text('Publicar'),
                  )
                : null,
          ),
          if (_items.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xxl),
              child: EmptyState(
                icon: Icons.campaign_outlined,
                title: 'No hay anuncios',
                message: _canManage
                    ? 'Publica el primer anuncio interno de la empresa.'
                    : 'Cuando la dirección publique un anuncio, aparecerá aquí.',
              ),
            )
          else
            for (final a in _items) ...[
              _AnnouncementCard(
                announcement: a,
                canManage: _canManage,
                busy: _busyId == a.id,
                onEdit: () => _openForm(existing: a),
                onDelete: () => _delete(a),
                onViews: () => _openViews(a),
                onConfirm: (attending) => _confirm(a, attending: attending),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
        ],
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({
    required this.announcement,
    required this.canManage,
    required this.busy,
    required this.onEdit,
    required this.onDelete,
    required this.onViews,
    required this.onConfirm,
  });

  final InternalAnnouncement announcement;
  final bool canManage;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onViews;
  final ValueChanged<bool> onConfirm;

  static String _dt(DateTime d) {
    final l = d.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(l.day)}/${two(l.month)}/${l.year} ${two(l.hour)}:${two(l.minute)}';
  }

  ({String label, AppBadgeVariant variant}) get _status {
    final a = announcement;
    if (!a.active) {
      return (label: 'Finalizado', variant: AppBadgeVariant.neutral);
    }
    if (a.eventAt != null) {
      return (label: 'Reunión', variant: AppBadgeVariant.info);
    }
    return (label: 'Activo', variant: AppBadgeVariant.success);
  }

  @override
  Widget build(BuildContext context) {
    final a = announcement;
    final st = _status;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  a.title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              AppBadge(label: st.label, variant: st.variant),
              if (canManage)
                _busyOrMenu(context)
              else
                const SizedBox.shrink(),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            a.body,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
          ),
          const SizedBox(height: AppSpacing.md),

          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _meta(
                a.isGeneral ? Icons.public : Icons.apartment_outlined,
                a.isGeneral ? 'Toda la empresa' : a.areaNames,
              ),
              if (a.eventAt != null)
                _meta(Icons.event_outlined, 'Reunión: ${_dt(a.eventAt!)}'),
              if ((a.locationLabel ?? '').isNotEmpty)
                _meta(Icons.place_outlined, a.locationLabel!),
              if (a.createdAt != null)
                _meta(Icons.schedule_outlined, 'Publicado ${_dt(a.createdAt!)}'),
            ],
          ),

          // ---- vista del director: agregados + acceso al historial ----
          if (canManage && a.audienceCount != null) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                _meta(Icons.visibility_outlined,
                    '${a.viewCount ?? 0}/${a.audienceCount} vistas'),
                if (a.requiresConfirmation) ...[
                  const SizedBox(width: AppSpacing.md),
                  _meta(Icons.how_to_reg_outlined,
                      '${a.confirmedYes ?? 0} sí · ${a.confirmedNo ?? 0} no'),
                ],
                const Spacer(),
                TextButton(
                  onPressed: onViews,
                  child: const Text('Ver visualizaciones'),
                ),
              ],
            ),
          ],

          // ---- vista del resto: confirmar asistencia ----
          if (!canManage && a.requiresConfirmation) ...[
            const Divider(color: AppColors.surfaceBorder, height: AppSpacing.xl),
            const Text(
              '¿Asistirás?',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: busy ? null : () => onConfirm(true),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Asistiré'),
                    style: FilledButton.styleFrom(
                      backgroundColor: a.myConfirmation == 'si'
                          ? AppColors.success
                          : AppColors.surface,
                      foregroundColor: a.myConfirmation == 'si'
                          ? AppColors.bgBase
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : () => onConfirm(false),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('No asistiré'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: a.myConfirmation == 'no'
                          ? AppColors.warning
                          : AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
            if (a.myConfirmation == 'si' && a.eventAt != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  const Icon(Icons.notifications_active_outlined,
                      size: 13, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Recibirás un recordatorio cada día hasta la reunión.',
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _busyOrMenu(BuildContext context) {
    if (busy) {
      return const Padding(
        padding: EdgeInsets.only(left: AppSpacing.sm),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return PopupMenuButton<String>(
      onSelected: (v) {
        switch (v) {
          case 'edit':
            onEdit();
          case 'views':
            onViews();
          case 'delete':
            onDelete();
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'edit', child: Text('Editar')),
        PopupMenuItem(value: 'views', child: Text('Ver visualizaciones')),
        PopupMenuItem(value: 'delete', child: Text('Eliminar')),
      ],
    );
  }

  Widget _meta(IconData icon, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.textMuted),
          const SizedBox(width: 4),
          Text(text,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
        ],
      );
}
