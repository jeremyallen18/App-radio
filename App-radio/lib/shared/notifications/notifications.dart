import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/core/api_config.dart';
import 'package:doliv_social/core/notifications_controller.dart';
import 'package:doliv_social/core/route_refresh.dart';
import 'package:doliv_social/shared/auth/login.dart';
import 'package:doliv_social/shared/notifications/notification_router.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with RouteAwareRefresh<NotificationsScreen> {
  List<dynamic> _notifications = [];
  bool _loading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  @override
  void onRouteReenter() => _fetchNotifications();

  Future<void> _fetchNotifications() async {
    setState(() {
      _loading = true;
      _hasError = false;
    });
    final token = await secureStorage.readSecureData(key);
    try {
      final response = await http.get(
        Uri.parse('$kBaseUrl/notifications'),
        headers: <String, String>{'Authorization': token ?? ''},
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        setState(() {
          _notifications = decoded['notifications'] ?? [];
          _loading = false;
        });
        // Mantiene la campana (y cualquier contador) sincronizados con lo que
        // esta pantalla acaba de cargar.
        final int? serverUnread = (decoded['unreadCount'] as num?)?.toInt();
        if (serverUnread != null) {
          NotificationsController.instance.setUnread(serverUnread);
        } else {
          NotificationsController.instance.setUnreadFromList(_notifications);
        }
      } else {
        setState(() {
          _hasError = true;
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _loading = false;
      });
    }
  }

  Future<void> _markRead(dynamic notification) async {
    if (notification['readAt'] != null) return;
    final token = await secureStorage.readSecureData(key);
    try {
      final response = await http.post(
        Uri.parse('$kBaseUrl/notifications/${notification['id']}/read'),
        headers: <String, String>{'Authorization': token ?? ''},
      );
      if (response.statusCode == 200) {
        NotificationsController.instance.decrement();
        if (mounted) {
          setState(() =>
              notification['readAt'] = DateTime.now().toIso8601String());
        }
      }
    } catch (_) {}
  }

  /// Toque en una notificación: se marca como leída y se abre la pantalla
  /// correspondiente a su tipo (ver [NotificationRouter]).
  Future<void> _onTapNotification(dynamic notification) async {
    await _markRead(notification);
    if (!mounted) return;
    await NotificationRouter.open(context, notification as Map);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        leading: AppBackButton.leadingFor(context),
        automaticallyImplyLeading: false,
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      body: RefreshIndicator(
        onRefresh: _fetchNotifications,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const LoadingState();
    if (_hasError) return ErrorState(onRetry: _fetchNotifications);
    if (_notifications.isEmpty) {
      return const EmptyState(
        icon: Icons.notifications_none_outlined,
        title: 'No tienes notificaciones',
        message: 'Cuando algo requiera tu atención, aparecerá aquí.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      itemCount: _notifications.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final n = _notifications[index];
        return NotificationTile(
          type: n['type']?.toString(),
          message: n['message']?.toString() ?? '',
          createdAt: n['createdAt']?.toString(),
          unread: n['readAt'] == null,
          onTap: () => _onTapNotification(n),
        );
      },
    );
  }
}
