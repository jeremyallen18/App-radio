import 'package:doliv_social/shared/auth/login.dart';
import 'package:doliv_social/shared/notifications/notifications.dart';
import 'package:doliv_social/shared/radio/radio_player_sheet.dart';
import 'package:flutter/material.dart';
import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/models/models.dart';
import 'package:doliv_social/core/session.dart';
import 'package:doliv_social/core/notifications_controller.dart';

/// Header flotante de la app: un panel de vidrio (navy translúcido, borde
/// fino, sombra suave) separado de los bordes de la pantalla. De izquierda a
/// derecha: menú (solo si la pantalla tiene Drawer), chip de rol, y a la
/// derecha el control de radio y la campana de notificaciones, cada bloque
/// separado por una línea fina.
class MyAppBar extends StatefulWidget implements PreferredSizeWidget {
  const MyAppBar({super.key});

  @override
  State<MyAppBar> createState() => _MyAppBarState();

  @override
  Size get preferredSize => const Size.fromHeight(96);
}

class _MyAppBarState extends State<MyAppBar> {
  AppRole? _role;

  Future<void> _loadRole() async {
    final token = await secureStorage.readSecureData(key);
    final profile = await Session.fetchCurrentUser(token ?? '');
    if (!mounted) return;
    setState(() => _role = profile?.role);
  }

  @override
  void initState() {
    super.initState();
    NotificationsController.instance.refresh(force: true);
    _loadRole();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bgBase,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, 0,
          ),
          child: GlassPanel(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm, vertical: 5,
              ),
              child: Row(
                children: [
                  // Menú hamburguesa: solo cuando la pantalla trae Drawer
                  // (inicio, tablero y progreso lo pasan a su Scaffold).
                  Builder(
                    builder: (context) {
                      final hasDrawer =
                          Scaffold.maybeOf(context)?.hasDrawer ?? false;
                      if (!hasDrawer) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.sm),
                        child: _CircleIconButton(
                          icon: Icons.menu_rounded,
                          tooltip: 'Menú',
                          onTap: () => Scaffold.of(context).openDrawer(),
                        ),
                      );
                    },
                  ),
                  _RoleChip(
                    label: (_role ?? AppRole.employee).shortLabel,
                  ),
                  // Radio + campana, pegados a la derecha. La etiqueta de la
                  // radio se encoge (y desaparece) antes que nada si falta ancho.
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const _VDivider(),
                        const SizedBox(width: AppSpacing.xs),
                        Flexible(
                          child: RadioPlayerButton(
                            onExpand: () => showRadioPlayer(context),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        const _VDivider(),
                        const SizedBox(width: AppSpacing.xs),
                        const _NotificationsBell(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Botón redondo del header (menú, campana): círculo tenue + ícono claro.
class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.surface,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 34,
            height: 34,
            child: Icon(icon, color: AppColors.textPrimary, size: 19),
          ),
        ),
      ),
    );
  }
}

/// Chip del rol: contorno azul acento con ícono de persona.
class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 150),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.person_outline_rounded, size: 15, color: AppColors.accent),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.accent,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VDivider extends StatelessWidget {
  const _VDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 20, color: AppColors.surfaceBorder);
  }
}

/// Campana + contador de no leídas. Al volver de la pantalla se resincroniza.
class _NotificationsBell extends StatelessWidget {
  const _NotificationsBell();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: NotificationsController.instance,
      builder: (context, _) {
        final int unread = NotificationsController.instance.unreadCount;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            _CircleIconButton(
              icon: Icons.notifications_none_rounded,
              tooltip: 'Notificaciones',
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NotificationsScreen(),
                  ),
                );
                NotificationsController.instance.refresh(force: true);
              },
            ),
            if (unread > 0)
              Positioned(
                right: -1,
                top: -1,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.surface, width: 1.5),
                  ),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    unread > 99 ? '99+' : '$unread',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
