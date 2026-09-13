import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:doliv_social/core/api_config.dart';
import 'package:doliv_social/core/session_keys.dart' show secureStorage, key;
import 'package:doliv_social/models/broadcast_notice.dart';

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
  final ValueNotifier<BroadcastNotice?> bulletin = ValueNotifier(null);
  final Set<String> _seenBulletins = {};
  String? _bulletinSession;
  bool _hasBulletinBaseline = false;
  int _sessionGeneration = 0;
  int get sessionGeneration => _sessionGeneration;

  void showBulletin(BroadcastNotice notice) => bulletin.value = notice;

  void dismissBulletin(BroadcastNotice notice) {
    if (identical(bulletin.value, notice)) bulletin.value = null;
  }

  void _bindBulletinSession(String token) {
    if (_bulletinSession == token) return;
    _bulletinSession = token;
    _hasBulletinBaseline = false;
    _seenBulletins.clear();
    bulletin.value = null;
  }

  bool _rememberBulletin(String id) {
    if (!_seenBulletins.add(id)) return false;
    if (_seenBulletins.length > 256) {
      _seenBulletins.remove(_seenBulletins.first);
    }
    return true;
  }

  /// Push and HTTP use the same notification id, so arrival order cannot
  /// produce two banners. A late callback cannot resurrect a dismissed notice.
  void receiveAnnouncement(Map<String, String> data, {required String token}) {
    if (data['type'] != 'internal_announcement' || token.isEmpty) return;
    _bindBulletinSession(token);
    final id = data['notifId'] ?? data['id'] ?? '';
    if (id.isEmpty || !_rememberBulletin(id)) return;
    showBulletin(BroadcastNotice(
      id: id,
      title: (data['title'] ?? '').trim().isEmpty
          ? 'Nuevo anuncio interno'
          : data['title']!,
      preview: data['body'] ?? data['message'] ?? '',
      data: data,
    ));
  }

  void _observeAnnouncements(List notifications, String token) {
    _bindBulletinSession(token);
    Map<String, String>? newest;
    for (final item in notifications) {
      if (item is! Map || item['type'] != 'internal_announcement') continue;
      final id = item['id']?.toString() ?? '';
      if (id.isEmpty || !_rememberBulletin(id)) continue;
      if (_hasBulletinBaseline && item['readAt'] == null && newest == null) {
        newest =
            item.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
      }
    }
    // The initial page is history, not a burst of incoming transmissions.
    _hasBulletinBaseline = true;
    if (newest != null) {
      showBulletin(BroadcastNotice(
        id: newest['id']!,
        title: 'Nuevo anuncio interno',
        preview: newest['message'] ?? '',
        data: newest,
      ));
    }
  }

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
    final generation = _sessionGeneration;
    try {
      final token = await secureStorage.readSecureData(key);
      if (generation != _sessionGeneration) return;
      if (token == null || token.isEmpty) {
        bulletin.value = null;
        _setUnread(0);
        return;
      }
      final res = await http.get(
        Uri.parse('$kBaseUrl/notifications'),
        headers: <String, String>{'Authorization': token},
      ).timeout(const Duration(seconds: 10));
      if (generation != _sessionGeneration) return;
      if (res.statusCode == 200) {
        final decoded = json.decode(res.body) as Map<String, dynamic>;
        _observeAnnouncements(
            (decoded['notifications'] as List?) ?? const [], token);
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
    _sessionGeneration++;
    _bulletinSession = null;
    _hasBulletinBaseline = false;
    _seenBulletins.clear();
    bulletin.value = null;
    _lastFetch = null;
    _setUnread(0);
  }

  void _setUnread(int value) {
    if (value == _unreadCount) return;
    _unreadCount = value;
    notifyListeners();
  }
}
