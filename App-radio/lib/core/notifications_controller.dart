import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:doliv_social/core/api_config.dart';
import 'package:doliv_social/core/session_keys.dart' show secureStorage, key;

/// Fuente única del número de notificaciones sin leer; todas las campanas
/// escuchan este singleton. El conteo lo da el backend (`GET /notifications` →
/// `unreadCount`); si falta, se cuenta la lista.
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
      if (token == null || token.isEmpty) {
        _setUnread(0);
        return;
      }
      final res = await http.get(
        Uri.parse('$kBaseUrl/notifications'),
        headers: <String, String>{'Authorization': token},
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

  /// Fija el conteo desde una lista ya cargada, sin segunda llamada.
  void setUnreadFromList(Iterable notifications) {
    _lastFetch = DateTime.now();
    _setUnread(
      notifications.where((n) => n is Map && n['readAt'] == null).length,
    );
  }

  /// Fija el conteo a un valor exacto ya devuelto por el backend.
  void setUnread(int value) {
    _lastFetch = DateTime.now();
    _setUnread(value < 0 ? 0 : value);
  }

  /// Ajuste optimista al marcar una notificación como leída.
  void decrement([int by = 1]) {
    if (_unreadCount <= 0) return;
    _setUnread((_unreadCount - by).clamp(0, _unreadCount));
  }

  /// Al cerrar sesión: borra el contador para no filtrarlo a otra cuenta.
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
