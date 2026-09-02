import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../design/design.dart';
import '../home_page/tasks.dart';
import '../utils/api_config.dart';
import '../utils/session.dart';
import 'chat.dart';
import 'login.dart';
import 'teamDetail.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<dynamic> _notifications = [];
  bool _loading = true;
  bool _hasError = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
    // Mientras la pantalla está abierta, se refresca sola cada pocos
    // segundos para que las notificaciones nuevas (mensajes, tareas,
    // altas/bajas de miembros) aparezcan sin necesidad de deslizar para
    // refrescar manualmente.
    _pollTimer = Timer.periodic(
      const Duration(seconds: 8),
      (_) => _fetchNotifications(showSpinner: false),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchNotifications({bool showSpinner = true}) async {
    // Los refrescos automáticos en segundo plano no deben tapar la lista
    // con el spinner de carga completo; solo la primera carga y el
    // "pull to refresh" manual lo muestran.
    if (showSpinner) {
      setState(() {
        _loading = true;
        _hasError = false;
      });
    }
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
          _hasError = false;
        });
      } else if (showSpinner) {
        // Un refresco en segundo plano que falla no debe tapar la lista
        // que ya se ve en pantalla con el estado de error.
        setState(() {
          _hasError = true;
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      if (showSpinner) {
        setState(() {
          _hasError = true;
          _loading = false;
        });
      }
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

  // Elimina una notificación puntual (o, si viene de un grupo tipo WhatsApp,
  // todas las que integran ese grupo) en el backend y la quita de la lista
  // local sin esperar al próximo refresco.
  //
  // Antes solo se revisaba si `http.delete` lanzaba una excepción (corte de
  // red). Pero un 401/500 del servidor no lanza excepción en Dart, así que
  // si el borrado fallaba del lado del servidor la app igual la quitaba de
  // pantalla como si nada, y el siguiente refresco automático (cada 8s) la
  // traía de vuelta — la notificación "reaparecía" en vez de quedar borrada
  // de verdad. Ahora se revisa el código de estado de cada respuesta; si
  // algo no se pudo borrar, en vez de confiar en la lista local optimista
  // se refresca desde el backend, para no dejar fantasmas que reaparezcan
  // sin explicación.
  Future<void> _deleteNotifications(List<dynamic> notifications) async {
    final ids = notifications.map((n) => n['id']).toSet();
    setState(() => _notifications.removeWhere((n) => ids.contains(n['id'])));
    final token = await secureStorage.readSecureData(key);
    bool anyFailed = false;
    for (final n in notifications) {
      try {
        final response = await http.delete(
          Uri.parse('$kBaseUrl/notifications/${n['id']}'),
          headers: <String, String>{'Authorization': token ?? ''},
        );
        // 404 = esa notificación ya no existía en el servidor (por ejemplo,
        // borrada desde otro dispositivo): el resultado que le importa al
        // usuario -que ya no esté ahí- igual se cumplió, así que no cuenta
        // como fallo.
        if (response.statusCode != 200 && response.statusCode != 404) {
          anyFailed = true;
        }
      } catch (_) {
        anyFailed = true;
      }
    }
    if (!mounted) return;
    if (anyFailed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Algunas notificaciones no se pudieron eliminar')),
      );
      await _fetchNotifications(showSpinner: false);
    }
  }

  Future<void> _confirmDeleteAll() async {
    if (_notifications.isEmpty) return;
    final bool? confirmed = await showAppConfirmDialog(
      context,
      title: 'Eliminar notificaciones',
      message: 'Se eliminarán todas tus notificaciones. Esta acción no se puede deshacer.',
      confirmLabel: 'Eliminar',
      danger: true,
    );
    if (confirmed != true || !mounted) return;
    final all = List<dynamic>.from(_notifications);
    setState(() => _notifications = []);
    final token = await secureStorage.readSecureData(key);
    try {
      final response = await http.delete(
        Uri.parse('$kBaseUrl/notifications'),
        headers: <String, String>{'Authorization': token ?? ''},
      );
      // Antes solo se restauraba la lista si `http.delete` lanzaba una
      // excepción; un error del servidor (401/500) llega como respuesta
      // normal, no como excepción, así que un fallo silencioso dejaba la
      // pantalla vacía mientras el backend seguía con todas las
      // notificaciones intactas — la próxima vez que se abriera la
      // pantalla (o en el siguiente refresco automático), todo "el rastro"
      // volvía a aparecer de golpe.
      if (response.statusCode != 200) {
        if (mounted) {
          setState(() => _notifications = all);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudieron eliminar las notificaciones')),
          );
        }
      }
    } catch (_) {
      // Si falla, se restauran para no dar una falsa sensación de éxito.
      if (mounted) {
        setState(() => _notifications = all);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error de red al eliminar las notificaciones')),
        );
      }
    }
  }

  // Agrupa las notificaciones de mensajes (mismo equipo) en una sola
  // entrada al estilo WhatsApp: se ve el mensaje más reciente y un "+N"
  // con la cantidad de mensajes adicionales de esa misma conversación. El
  // resto de tipos de notificación se muestran una por una, como antes.
  List<_NotificationGroup> _buildDisplayGroups() {
    final groups = <_NotificationGroup>[];
    final seenMessageTeams = <String>{};
    for (final n in _notifications) {
      if (n['type']?.toString() == 'message_received') {
        final teamId = n['teamId']?.toString() ?? '';
        if (seenMessageTeams.contains(teamId)) continue;
        seenMessageTeams.add(teamId);
        final sameTeam = _notifications
            .where((other) =>
                other['type']?.toString() == 'message_received' &&
                (other['teamId']?.toString() ?? '') == teamId)
            .toList();
        groups.add(_NotificationGroup(items: sameTeam));
      } else {
        groups.add(_NotificationGroup(items: [n]));
      }
    }
    return groups;
  }

  // Al tocar una notificación ("de enterado"): se marca como leída y,
  // además, se navega a la pantalla que corresponde a lo que la
  // notificación anuncia (tarea asignada -> pestaña de tareas pendientes,
  // mensaje -> chat de ese grupo, alta de miembro/líder -> detalle de ese
  // equipo). El tipo es el que ya emite el backend (notify_user() en
  // hive-backend/helpers.php); tipos sin destino de pantalla (baja de
  // equipo, asignaciones de departamento, etc.) solo se marcan como leídos.
  Future<void> _handleTapGroup(_NotificationGroup group) async {
    // Un grupo de mensajes puede traer varias notificaciones sin leer de la
    // misma conversación: al tocarlo se marcan todas como leídas de una vez,
    // igual que al abrir un chat en WhatsApp.
    for (final n in group.items) {
      await _markRead(n);
    }
    await _handleTap(group.representative, alreadyMarkedRead: true);
  }

  Future<void> _handleTap(dynamic notification, {bool alreadyMarkedRead = false}) async {
    if (!alreadyMarkedRead) await _markRead(notification);
    if (!mounted) return;
    final String? type = notification['type']?.toString();
    final String? teamId = notification['teamId']?.toString();
    switch (type) {
      case 'task_assigned':
      case 'task_completed':
      case 'task_approved':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TaskFocusScreen()),
        );
        break;
      case 'message_received':
        if (teamId != null && teamId.isNotEmpty) {
          await _openChat(teamId);
        }
        break;
      case 'member_added':
      case 'leader_assigned':
      case 'admin_added':
      case 'admin_removed':
        if (teamId != null && teamId.isNotEmpty) {
          await _openTeam(teamId);
        }
        break;
      default:
        break;
    }
  }

  Future<void> _openChat(String teamId) async {
    final token = await secureStorage.readSecureData(key);
    final email = await Session.resolveEmail(token as String?);
    if (!mounted || email == null || email.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChatScreen(teamId: teamId, myEmail: email)),
    );
  }

  // t_detail necesita el mapa completo del equipo (no solo su id), así que
  // se resuelve contra /team/showTeams —el mismo endpoint que ya alimenta
  // la pestaña "Equipos"— y se busca el equipo con ese id.
  Future<void> _openTeam(String teamId) async {
    final token = await secureStorage.readSecureData(key);
    try {
      final response = await http.get(
        Uri.parse('$kBaseUrl/team/showTeams'),
        headers: <String, String>{'Authorization': token ?? ''},
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final List<dynamic> teams = decoded['teams'] ?? [];
        dynamic match;
        for (final t in teams) {
          if (t['_id']?.toString() == teamId) {
            match = t;
            break;
          }
        }
        if (match != null) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => t_detail(team: match)),
          );
          return;
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el equipo')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error de red al abrir el equipo')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        actions: [
          if (_notifications.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Eliminar todas',
              onPressed: _confirmDeleteAll,
            ),
        ],
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
    final groups = _buildDisplayGroups();
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      itemCount: groups.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final group = groups[index];
        final n = group.representative;
        return NotificationTile(
          type: n['type']?.toString(),
          message: n['message']?.toString() ?? '',
          createdAt: n['createdAt']?.toString(),
          unread: group.items.any((item) => item['readAt'] == null),
          extraCount: group.items.length - 1,
          onTap: () => _handleTapGroup(group),
          onDelete: () => _deleteNotifications(group.items),
        );
      },
    );
  }
}

/// Agrupa una o varias notificaciones (ver [_buildDisplayGroups]) que se
/// muestran como una sola tarjeta en la lista.
class _NotificationGroup {
  _NotificationGroup({required this.items});

  /// Ordenadas igual que llegan del backend (más reciente primero).
  final List<dynamic> items;

  dynamic get representative => items.first;
}
