import 'package:doliv_social/shared/auth/login.dart';
import 'package:doliv_social/shared/notifications/notifications.dart';
import 'package:doliv_social/shared/radio/radio_player_sheet.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/models/models.dart';
import 'package:doliv_social/core/api_config.dart';
import 'package:doliv_social/core/session.dart';

class MyAppBar extends StatefulWidget implements PreferredSizeWidget {
  const MyAppBar({Key? key}) : super(key: key);

  @override
  _MyAppBarState createState() => _MyAppBarState();

  @override
  Size get preferredSize => Size.fromHeight(132);
}

class _MyAppBarState extends State<MyAppBar> {
  String userName="";
  int unreadCount = 0;
  String? _photoUrl;
  AppRole? _role;

  Future<void> unreadCountAPI() async {
    dynamic storedValue = await secureStorage.readSecureData(key);
    final response = await http.get(
      Uri.parse('$kBaseUrl/notifications'),
      headers: <String, String>{'Authorization': storedValue ?? ''},
    );
    if (response.statusCode == 200 && mounted) {
      final decoded = json.decode(response.body);
      final List<dynamic> notifications = decoded['notifications'] ?? [];
      setState(() {
        unreadCount = notifications.where((n) => n['readAt'] == null).length;
      });
    }
  }

  Future<void> nameAPI() async {
    dynamic storedValue = await secureStorage.readSecureData(key);

    const String apiUrl =
        '$kBaseUrl/user/sendName';

    final response = await http.get(
      Uri.parse(apiUrl),
      headers: <String, String>{
        'Authorization': storedValue,
      },
    );

    if (response.statusCode == 200) {
      final String data = json.decode(response.body);
      setState(() {
        userName = data;
      });
    } else {
      print('Error: ${response.statusCode}');
    }
  }

  Future<void> _loadPhoto() async {
    final token = await secureStorage.readSecureData(key);
    final profile = await Session.fetchCurrentUser(token ?? '');
    if (!mounted) return;
    setState(() {
      _photoUrl = profile?.photoUrl;
      _role = profile?.role;
    });
  }

  @override
  void initState() {
    super.initState();
    nameAPI();
    unreadCountAPI();
    _loadPhoto();
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: AppColors.surface,
              backgroundImage: _photoUrl != null
                  ? NetworkImage(_photoUrl!) as ImageProvider
                  : const AssetImage('lib/assets/prof.png'),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '¡Hola!',
                    style: TextStyle(fontSize: 14, color: AppColors.textMuted),
                  ),
                  Text(
                    userName,
                    style: const TextStyle(
                      fontSize: 24.0,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  AppBadge(
                    label: _role?.label ?? AppRole.employee.label,
                    variant: AppBadgeVariant.info,
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RadioPlayerButton(onExpand: () => showRadioPlayer(context)),
                const SizedBox(width: AppSpacing.sm),
                Stack(
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
                            MaterialPageRoute(builder: (context) => const NotificationsScreen()),
                          );
                          unreadCountAPI();
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
                          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                          child: Text(
                            '$unreadCount',
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 10),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
