import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../utils/api_config.dart';
import 'login.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<dynamic> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
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
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
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
      if (response.statusCode == 200 && mounted) {
        setState(() => notification['readAt'] = DateTime.now().toIso8601String());
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 8, 18, 43),
        foregroundColor: Colors.white,
        title: const Text('Notificaciones'),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchNotifications,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _notifications.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 120),
                      Center(child: Text('No tienes notificaciones')),
                    ],
                  )
                : ListView.builder(
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) {
                      final n = _notifications[index];
                      final bool unread = n['readAt'] == null;
                      return ListTile(
                        leading: Icon(
                          Icons.notifications,
                          color: unread ? Colors.indigo : Colors.grey,
                        ),
                        title: Text(n['message'] ?? ''),
                        subtitle: Text(n['createdAt'] ?? ''),
                        tileColor: unread ? Colors.indigo.withOpacity(0.08) : null,
                        onTap: () => _markRead(n),
                      );
                    },
                  ),
      ),
    );
  }
}
