import 'dart:async';
import 'dart:convert';

import 'package:brl_task4/screens/login.dart';
import 'package:brl_task4/screens/notifications.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../utils/api_config.dart';
import '../design/theme/theme_controller.dart';
import '../design/tokens/colors.dart';

class MyAppBar extends StatefulWidget implements PreferredSizeWidget {
  const MyAppBar({Key? key}) : super(key: key);

  @override
  _MyAppBarState createState() => _MyAppBarState();

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight + 76);
}

class _MyAppBarState extends State<MyAppBar> {
  String userName="";
  int unreadCount = 0;
  Timer? _pollTimer;

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
    }
  }

  @override
  void initState() {
    super.initState();
    nameAPI();
    unreadCountAPI();
    // Refresca el contador de notificaciones sin que el usuario tenga que
    // entrar y salir de la pantalla de notificaciones: así el badge se
    // siente "en tiempo real" (nuevo mensaje de chat, tarea asignada,
    // alguien agregado/salido del equipo, etc.) mientras se navega la app.
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) => unreadCountAPI());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        // Degradado de marca (siempre azul marino/azul medio) en vez de un
        // negro/índigo fijo: así el header se ve intencional tanto en modo
        // claro como en modo oscuro, sin depender del modo activo.
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.brandBlue, AppColors.brandNavy],
        ),
      ),
      padding: EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 35,
                backgroundImage: AssetImage('lib/assets/prof.png'),
              ),
              SizedBox(width: 15),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 20),
                  Text(
                    '¡Hola!',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                  Text(
                    userName,
                    style: TextStyle(
                      fontSize: 24.0,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.notifications,
                      color: Colors.white,
                    ),
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const NotificationsScreen()),
                      );
                      unreadCountAPI();
                    },
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text(
                          '$unreadCount',
                          style: const TextStyle(color: Colors.white, fontSize: 10),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              // Botón de cambio de modo claro/oscuro para toda la app,
              // justo debajo de la campanita de notificaciones.
              AnimatedBuilder(
                animation: ThemeController.instance,
                builder: (context, _) {
                  final isDark = ThemeController.instance.isDark;
                  return IconButton(
                    tooltip: isDark ? 'Cambiar a modo claro' : 'Cambiar a modo oscuro',
                    icon: Icon(
                      isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                      color: Colors.white,
                    ),
                    onPressed: () => ThemeController.instance.toggle(),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
