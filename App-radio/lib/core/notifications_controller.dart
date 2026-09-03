import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:doliv_social/core/api_config.dart';
import 'package:doliv_social/core/session_keys.dart' show secureStorage, key;

/// Única fuente de verdad para el número de notificaciones sin leer.
///
/// Antes cada `MyAppBar` (una instancia por pantalla) pedía el conteo por su
/// cuenta y solo lo refrescaba al volver de la pantalla de notificaciones
/// abierta desde ESA campana; distintas pantallas podían mostrar números
/// distintos. Ahora todas escuchan este singleton y ven el mismo valor.
///
/// El número autoritativo lo calcula el backend (`GET /notifications` ->
/// `unreadCount`); si un backend viejo no lo manda, se cuenta la lista.
class NotificationsController extends ChangeNotifier {
  NotificationsController._();
  static final NotificationsController instance = NotificationsController._();

  int _unreadCount = 0;
  int get unreadCount => _unreadCount;

  bool _loading = false;
  bool get loading => _loading;

  DateTime? _lastFetch;

  /// Pide el conteo al backend. Se ignora si ya se pidió hace muy poco, salvo
  /// [force] (tras marcar leída, abrir la pantalla, login…). Nunca lanza.
  Future<void> refresh({bool force = false}) async {
    if (_loading) return;
    if (!force &&
        _lastFetch != null &&
        DateTime.now().difference(_lastFetch!) < const Duration(seconds: 4)) {
      return;
    }
    _loading = true;
    try {
      final token = await secureStorage.readSecureData(key);
      if (token == null || (token is String && token.isEmpty)) {
        _setUnread(0);
        return;
      }
      final res = await http.get(
        Uri.parse('$kBaseUrl/notifications'),
        headers: <String, String>{'Authorization': token as String},
      );
      if (res.statusCode == 200) {
        final decoded = json.decode(res.body) as Map<String, dynamic>;
        final int count = (decoded['unreadCount'] as num?)?.toInt() ??
            (((decoded['notifications'] as List?) ?? const [])
                .where((n) => n is Map && n['readAt'] == null)
                .length);
        _lastFetch = DateTime.now();
        _setUnread(count);
      }
    } catch (_) {
      // Sin red: se conserva el último valor conocido.
    } finally {
      _loading = false;
    }
  }

  /// Fija el conteo a partir de una lista ya cargada por la pantalla de
  /// notificaciones, para no hacer una segunda llamada.
  void setUnreadFromList(Iterable notifications) {
    _lastFetch = DateTime.now();
    _setUnread(
      notifications.where((n) => n is Map && n['readAt'] == null).length,
    );
  }

  /// Fija el conteo a un valor exacto (p. ej. el `unreadCount` que ya
  /// devolvió el backend en otra llamada).
  void setUnread(int value) {
    _lastFetch = DateTime.now();
    _setUnread(value < 0 ? 0 : value);
  }

  /// Ajuste optimista al marcar una notificación como leída.
  void decrement([int by = 1]) {
    if (_unreadCount <= 0) return;
    _setUnread((_unreadCount - by).clamp(0, _unreadCount));
  }

  /// Al cerrar sesión: borra el contador para que no se filtre a la
  /// siguiente cuenta que inicie sesión en el mismo dispositivo.
  void clear() {
    _lastFetch = null;
    _setUnread(0);
  }

  void _setUnread(int value) {
    if (value == _unreadCount) return;
    _unreadCount = value;
    notifyListeners();
  }
}
