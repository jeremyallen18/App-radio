import 'package:doliv_social/shared/auth/login.dart';
import 'package:doliv_social/shared/notifications/notifications.dart';
import 'package:doliv_social/shared/radio/radio_player_sheet.dart';
import 'package:flutter/material.dart';
import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/models/models.dart';
import 'package:doliv_social/core/session.dart';
import 'package:doliv_social/core/notifications_controller.dart';

class MyAppBar extends StatefulWidget implements PreferredSizeWidget {
  const MyAppBar({Key? key}) : super(key: key);

  @override
  _MyAppBarState createState() => _MyAppBarState();

  @override
  Size get preferredSize => Size.fromHeight(112);
}

class _MyAppBarState extends State<MyAppBar> {
  AppRole? _role;

  Future<void> _loadRole() async {
    final token = await secureStorage.readSecureData(key);
    final profile = await Session.fetchCurrentUser(token ?? '');
    if (!mounted) return;
    setState(() {
      _role = profile?.role;
    });
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
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Botón de menú hamburguesa: solo cuando la pantalla trae un
            // Drawer (inicio, tablero y progreso lo pasan a su Scaffold).
            Builder(
              builder: (context) {
                final hasDrawer = Scaffold.maybeOf(context)?.hasDrawer ?? false;
                if (!hasDrawer) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.menu, color: AppColors.textPrimary),
                      tooltip: 'Menú',
                      onPressed: () => Scaffold.of(context).openDrawer(),
                    ),
                  ),
                );
              },
            ),
            AppBadge(
              label: _role?.label ?? AppRole.employee.label,
              variant: AppBadgeVariant.info,
            ),
            const Spacer(),
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                RadioPlayerButton(onExpand: () => showRadioPlayer(context)),
                const SizedBox(width: AppSpacing.sm),
                AnimatedBuilder(
                  animation: NotificationsController.instance,
                  builder: (context, _) {
                    final int unreadCount =
                        NotificationsController.instance.unreadCount;
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          decoration: const BoxDecoration(
                            color: AppColors.surface,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.notifications_outlined,
                              color: AppColors.textPrimary,
                            ),
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        const NotificationsScreen()),
                              );
                              NotificationsController.instance
                                  .refresh(force: true);
                            },
                          ),
                        ),
                        if (unreadCount > 0)
                          Positioned(
                            right: 6,
                            top: 6,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: AppColors.error,
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                  minWidth: 16, minHeight: 16),
                              child: Text(
                                unreadCount > 99 ? '99+' : '$unreadCount',
                                style: const TextStyle(
                                    color: AppColors.textPrimary, fontSize: 10),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
