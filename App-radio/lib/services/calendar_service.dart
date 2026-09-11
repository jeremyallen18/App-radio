import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:doliv_social/models/calendar_event.dart';
import 'package:doliv_social/models/models.dart';
import 'package:doliv_social/core/api_config.dart';
import 'package:doliv_social/core/session_keys.dart' show secureStorage, key;

/// Error de calendario con mensaje en español listo para mostrar.
class CalendarException implements Exception {
  CalendarException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Cliente de /calendar y /events.
class CalendarApi {
  static Future<String> _token() async {
    final token = await secureStorage.readSecureData(key);
    return token ?? '';
  }

  /// Feed del calendario (actividades + eventos) en `[from, to]`. `scope`:
  /// manager `'department'`/`null`; director `'company'` o un `departmentId`.
  static Future<({List<CalendarActivity> activities, List<CalendarEvent> events, bool canManage})> feed({
    required DateTime from,
    required DateTime to,
    String? scope,
    String? departmentId,
  }) async {
    final uri = Uri.parse('$kBaseUrl/calendar').replace(
      queryParameters: <String, String>{
        'from': _ymd(from),
        'to': _ymd(to),
        if (scope != null && scope.isNotEmpty) 'scope': scope,
        if (departmentId != null && departmentId.isNotEmpty) 'departmentId': departmentId,
      },
    );
    final res = await _get(uri);
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    return (
      activities: ((decoded['activities'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => CalendarActivity.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      events: ((decoded['events'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => CalendarEvent.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      canManage: decoded['canManage'] == true,
    );
  }

  /// Crea un evento (solo director).
  static Future<CalendarEvent> createEvent(Map<String, dynamic> body) async {
    final res = await _postJson(Uri.parse('$kBaseUrl/events'), body);
    return CalendarEvent.fromJson(
      (jsonDecode(res.body) as Map<String, dynamic>)['event'] as Map<String, dynamic>,
    );
  }

  static Future<CalendarEvent> updateEvent(String id, Map<String, dynamic> body) async {
    final res = await _postJson(Uri.parse('$kBaseUrl/events/$id'), body);
    return CalendarEvent.fromJson(
      (jsonDecode(res.body) as Map<String, dynamic>)['event'] as Map<String, dynamic>,
    );
  }

  static Future<void> deleteEvent(String id) async {
    await _postJson(Uri.parse('$kBaseUrl/events/$id/delete'), const {});
  }

  /// Departamentos para el selector de alcance del director. Nunca lanza: ante
  /// un fallo devuelve lista vacía.
  static Future<List<DepartmentInfo>> departments() async {
    try {
      final res = await http.get(
        Uri.parse('$kBaseUrl/department/list'),
        headers: {'Authorization': await _token()},
      );
      if (res.statusCode != 200) return [];
      final List<dynamic> raw = jsonDecode(res.body)['departments'] ?? [];
      return raw
          .map((d) => DepartmentInfo.fromJson(Map<String, dynamic>.from(d)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // transporte

  static String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static Future<http.Response> _get(Uri uri) async {
    late final http.Response res;
    try {
      res = await http.get(uri, headers: {'Authorization': await _token()});
    } catch (_) {
      throw CalendarException('Se produjo un error de conexión. Inténtalo nuevamente.');
    }
    _ensureOk(res);
    return res;
  }

  static Future<http.Response> _postJson(Uri uri, Map<String, dynamic> body) async {
    late final http.Response res;
    try {
      res = await http.post(
        uri,
        headers: {
          'Authorization': await _token(),
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
    } catch (_) {
      throw CalendarException('Se produjo un error de conexión. Inténtalo nuevamente.');
    }
    _ensureOk(res);
    return res;
  }

  static void _ensureOk(http.Response res) {
    if (res.statusCode == 200) return;
    throw CalendarException(_extractMessage(res.body));
  }

  static String _extractMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final msg = decoded['message'] ?? decoded['error'];
        if (msg != null) return msg.toString();
      }
    } catch (_) {}
    return 'No se pudo completar la acción. Inténtalo nuevamente.';
  }
}
