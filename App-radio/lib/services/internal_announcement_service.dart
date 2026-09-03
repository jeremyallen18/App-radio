import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:doliv_social/models/internal_announcement.dart';
import 'package:doliv_social/core/api_config.dart';
import 'package:doliv_social/core/session_keys.dart' show secureStorage, key;

/// Error del módulo de anuncios internos con un mensaje ya listo para mostrar
/// en español (mismo contrato que `CalendarException`).
class InternalAnnouncementException implements Exception {
  InternalAnnouncementException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Cliente de /internal-announcements (hive-backend/internal_announcements.php).
/// Mismo patrón de transporte que `CalendarApi`.
class InternalAnnouncementApi {
  static Future<String> _token() async {
    final token = await secureStorage.readSecureData(key);
    return (token as String?) ?? '';
  }

  /// Tablero de anuncios. El director recibe todos (con agregados); el resto,
  /// solo los activos y visibles para él, y la llamada cuenta como
  /// visualización.
  static Future<({List<InternalAnnouncement> items, bool canManage})> list() async {
    final res = await _get(Uri.parse('$kBaseUrl/internal-announcements'));
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    return (
      items: ((decoded['items'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => InternalAnnouncement.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      canManage: decoded['canManage'] == true,
    );
  }

  /// Crea un anuncio (solo director). Ver `ia_body_or_fail` en el backend para
  /// las reglas de validación (se replican en el formulario).
  static Future<InternalAnnouncement> create(Map<String, dynamic> body) async {
    final res = await _postJson(Uri.parse('$kBaseUrl/internal-announcements'), body);
    return InternalAnnouncement.fromJson(
      (jsonDecode(res.body) as Map<String, dynamic>)['announcement'] as Map<String, dynamic>,
    );
  }

  static Future<InternalAnnouncement> update(String id, Map<String, dynamic> body) async {
    final res = await _postJson(Uri.parse('$kBaseUrl/internal-announcements/$id'), body);
    return InternalAnnouncement.fromJson(
      (jsonDecode(res.body) as Map<String, dynamic>)['announcement'] as Map<String, dynamic>,
    );
  }

  static Future<void> delete(String id) async {
    await _postJson(Uri.parse('$kBaseUrl/internal-announcements/$id/delete'), const {});
  }

  /// Confirma (o desmarca) asistencia. `attending` = false registra "no asisto".
  static Future<InternalAnnouncement> confirm(String id, {required bool attending}) async {
    final res = await _postJson(
      Uri.parse('$kBaseUrl/internal-announcements/$id/confirm'),
      {'status': attending ? 'si' : 'no'},
    );
    return InternalAnnouncement.fromJson(
      (jsonDecode(res.body) as Map<String, dynamic>)['announcement'] as Map<String, dynamic>,
    );
  }

  /// Historial de visualizaciones y confirmaciones (solo director).
  static Future<AnnouncementViewsReport> views(String id) async {
    final res = await _get(Uri.parse('$kBaseUrl/internal-announcements/$id/views'));
    return AnnouncementViewsReport.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  // ---- transporte ---------------------------------------------------

  static Future<http.Response> _get(Uri uri) async {
    late final http.Response res;
    try {
      res = await http.get(uri, headers: {'Authorization': await _token()});
    } catch (_) {
      throw InternalAnnouncementException(
          'Se produjo un error de conexión. Inténtalo nuevamente.');
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
      throw InternalAnnouncementException(
          'Se produjo un error de conexión. Inténtalo nuevamente.');
    }
    _ensureOk(res);
    return res;
  }

  static void _ensureOk(http.Response res) {
    if (res.statusCode == 200) return;
    throw InternalAnnouncementException(_extractMessage(res.body));
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
