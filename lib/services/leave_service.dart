import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'package:doliv_social/models/leave_request.dart';
import 'package:doliv_social/core/api_config.dart';
import 'package:doliv_social/core/session_keys.dart' show secureStorage, key;

/// Error de la gestión de permisos, con mensaje en español listo para mostrar.
/// El backend responde `{success:false, message:"..."}` en errores de negocio.
class LeaveException implements Exception {
  LeaveException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Cliente de /leave-requests/* y /admin/leave-requests/* (hive-backend).
/// Mismo patrón que `attendance_service.dart` / `directory_api.dart`.
class LeaveApi {
  static Future<String> _token() async {
    final token = await secureStorage.readSecureData(key);
    return (token as String?) ?? '';
  }

  /// Headers de autorización, p.ej. para `Image.network` de la evidencia.
  static Future<Map<String, String>> authHeaders() async =>
      {'Authorization': await _token()};

  /// URL del endpoint autenticado que sirve la evidencia de una solicitud.
  static String evidenceUrl(String id) => '$kBaseUrl/leave-requests/$id/evidence';

  // ---- empleado -------------------------------------------------

  /// Crea una solicitud. `evidence` es OBLIGATORIA para incapacidad; el
  /// backend la rechaza si falta.
  static Future<LeaveRequest> create({
    required LeaveType type,
    required DateTime start,
    required DateTime end,
    String? reason,
    File? evidence,
  }) async {
    final req = http.MultipartRequest('POST', Uri.parse('$kBaseUrl/leave-requests'))
      ..headers['Authorization'] = await _token()
      ..fields['type'] = type.apiValue
      ..fields['requestedStartDate'] = _ymd(start)
      ..fields['requestedEndDate'] = _ymd(end);
    if (reason != null && reason.trim().isNotEmpty) {
      req.fields['reason'] = reason.trim();
    }
    if (evidence != null) {
      req.files.add(await http.MultipartFile.fromPath('evidence', evidence.path));
    }

    late final http.StreamedResponse streamed;
    try {
      streamed = await req.send();
    } catch (_) {
      throw LeaveException('No se pudo completar la operación debido a un error de conexión.');
    }
    final res = await http.Response.fromStream(streamed);
    _ensureOk(res);
    return LeaveRequest.fromJson(_body(res)['request'] as Map<String, dynamic>);
  }

  static Future<List<LeaveRequest>> mine() async {
    final res = await _get(Uri.parse('$kBaseUrl/leave-requests/my'));
    return _list(res);
  }

  static Future<LeaveRequest> get(String id) async {
    final res = await _get(Uri.parse('$kBaseUrl/leave-requests/$id'));
    return LeaveRequest.fromJson(_body(res)['request'] as Map<String, dynamic>);
  }

  static Future<LeaveRequest> cancelMine(String id, {String? reason}) async {
    final res = await _postForm(
      Uri.parse('$kBaseUrl/leave-requests/$id/cancel'),
      {if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim()},
    );
    return LeaveRequest.fromJson(_body(res)['request'] as Map<String, dynamic>);
  }

  // ---- director ----------------------------------------------

  static Future<List<LeaveRequest>> adminList({
    LeaveStatus? status,
    LeaveType? type,
    String? employeeId,
  }) async {
    final uri = Uri.parse('$kBaseUrl/admin/leave-requests').replace(
      queryParameters: <String, String>{
        if (status != null) 'status': status.name,
        if (type != null) 'type': type.apiValue,
        if (employeeId != null && employeeId.isNotEmpty) 'employeeId': employeeId,
      },
    );
    final res = await _get(uri);
    return _list(res);
  }

  static Future<LeaveRequest> adminGet(String id) async {
    final res = await _get(Uri.parse('$kBaseUrl/admin/leave-requests/$id'));
    return LeaveRequest.fromJson(_body(res)['request'] as Map<String, dynamic>);
  }

  /// Ausencias del equipo (aprobadas + pendientes por defecto) cuyo rango se
  /// cruza con [from]..[to]. Opcionalmente acotado a un departamento.
  static Future<List<LeaveCalendarItem>> calendar({
    required DateTime from,
    required DateTime to,
    String? departmentId,
    LeaveStatus? status,
  }) async {
    String ymd(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final uri = Uri.parse('$kBaseUrl/admin/leave-requests/calendar').replace(
      queryParameters: <String, String>{
        'from': ymd(from),
        'to': ymd(to),
        if (departmentId != null && departmentId.isNotEmpty) 'departmentId': departmentId,
        if (status != null) 'status': status.name,
      },
    );
    final res = await _get(uri);
    return ((_body(res)['items'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => LeaveCalendarItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<LeaveRequest> approve(
    String id, {
    required DateTime approvedStart,
    required DateTime approvedEnd,
  }) async {
    final res = await _postForm(
      Uri.parse('$kBaseUrl/admin/leave-requests/$id/approve'),
      {
        'approvedStartDate': _ymd(approvedStart),
        'approvedEndDate': _ymd(approvedEnd),
      },
    );
    return LeaveRequest.fromJson(_body(res)['request'] as Map<String, dynamic>);
  }

  static Future<LeaveRequest> reject(String id, {required String reason}) async {
    final res = await _postForm(
      Uri.parse('$kBaseUrl/admin/leave-requests/$id/reject'),
      {'reason': reason.trim()},
    );
    return LeaveRequest.fromJson(_body(res)['request'] as Map<String, dynamic>);
  }

  /// Revoca un permiso aprobado. Conserva todo el historial de la aprobación.
  static Future<LeaveRequest> adminCancel(String id, {required String reason}) async {
    final res = await _postForm(
      Uri.parse('$kBaseUrl/admin/leave-requests/$id/cancel'),
      {'reason': reason.trim()},
    );
    return LeaveRequest.fromJson(_body(res)['request'] as Map<String, dynamic>);
  }

  // ---- transporte ------------------------------------------

  static String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static List<LeaveRequest> _list(http.Response res) =>
      ((_body(res)['requests'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => LeaveRequest.fromJson(Map<String, dynamic>.from(e)))
          .toList();

  static Map<String, dynamic> _body(http.Response res) =>
      jsonDecode(res.body) as Map<String, dynamic>;

  static Future<http.Response> _get(Uri uri) async {
    late final http.Response res;
    try {
      res = await http.get(uri, headers: {'Authorization': await _token()});
    } catch (_) {
      throw LeaveException('No se pudo completar la operación debido a un error de conexión.');
    }
    _ensureOk(res);
    return res;
  }

  static Future<http.Response> _postForm(Uri uri, Map<String, String> body) async {
    late final http.Response res;
    try {
      res = await http.post(uri, headers: {'Authorization': await _token()}, body: body);
    } catch (_) {
      throw LeaveException('No se pudo completar la operación debido a un error de conexión.');
    }
    _ensureOk(res);
    return res;
  }

  static void _ensureOk(http.Response res) {
    if (res.statusCode == 200) return;
    throw LeaveException(_extractMessage(res.body));
  }

  static String _extractMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final msg = decoded['message'] ?? decoded['error'];
        if (msg != null) return msg.toString();
      }
    } catch (_) {}
    return 'No se pudo completar la operación. Inténtalo nuevamente.';
  }
}
