import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'package:doliv_social/core/api_config.dart';
import 'package:doliv_social/core/session_keys.dart' show secureStorage, key;
import 'package:doliv_social/services/leave_service.dart' show LeaveException;

/// Un periodo consecutivo de faltas (días laborales lun-sáb ya pasados sin
/// asistencia ni permiso) que el trabajador puede justificar.
class AbsenceRun {
  AbsenceRun({
    required this.start,
    required this.end,
    required this.days,
    required this.requiresEvidence,
    required this.consecutive,
    required this.justificationStatus,
  });

  final DateTime start;
  final DateTime end;
  final int days;
  final bool requiresEvidence;
  final bool consecutive;

  /// 'ninguna' | 'pendiente' | 'aprobada' | 'rechazada'
  final String justificationStatus;

  bool get isPending => justificationStatus == 'pendiente';
  bool get isApproved => justificationStatus == 'aprobada';
  bool get isRejected => justificationStatus == 'rechazada';
  bool get canSubmit => justificationStatus == 'ninguna' || isRejected;

  factory AbsenceRun.fromJson(Map<String, dynamic> j) => AbsenceRun(
        start: DateTime.parse(j['startDate'].toString()),
        end: DateTime.parse(j['endDate'].toString()),
        days: (j['days'] as num?)?.toInt() ?? 1,
        requiresEvidence: j['requiresEvidence'] != false,
        consecutive: j['consecutive'] == true,
        justificationStatus: j['justificationStatus']?.toString() ?? 'ninguna',
      );
}

/// Una justificación de falta enviada por el trabajador.
class AbsenceJustification {
  AbsenceJustification({
    required this.id,
    required this.start,
    required this.end,
    required this.reason,
    required this.status,
    required this.statusLabel,
    required this.hasEvidence,
    required this.reviewNote,
    required this.createdAt,
  });

  final String id;
  final DateTime start;
  final DateTime end;
  final String? reason;

  /// 'pendiente' | 'aprobada' | 'rechazada'
  final String status;
  final String statusLabel;
  final bool hasEvidence;
  final String? reviewNote;
  final DateTime? createdAt;

  factory AbsenceJustification.fromJson(Map<String, dynamic> j) =>
      AbsenceJustification(
        id: j['id'].toString(),
        start: DateTime.parse(j['startDate'].toString()),
        end: DateTime.parse(j['endDate'].toString()),
        reason: j['reason']?.toString(),
        status: j['status']?.toString() ?? 'pendiente',
        statusLabel: j['statusLabel']?.toString() ?? 'Pendiente',
        hasEvidence: j['hasEvidence'] == true,
        reviewNote: j['reviewNote']?.toString(),
        createdAt: DateTime.tryParse(j['createdAt']?.toString() ?? ''),
      );
}

class AbsencesResult {
  AbsencesResult({required this.unjustified, required this.justifications});
  final List<AbsenceRun> unjustified;
  final List<AbsenceJustification> justifications;
}

/// Justificación con los datos del empleado, para el panel del director.
class AdminAbsenceJustification {
  AdminAbsenceJustification({required this.item, required this.employeeName});
  final AbsenceJustification item;
  final String employeeName;

  factory AdminAbsenceJustification.fromJson(Map<String, dynamic> j) =>
      AdminAbsenceJustification(
        item: AbsenceJustification.fromJson(j),
        employeeName: (j['employee'] is Map
                ? (j['employee']['name']?.toString())
                : null) ??
            'Empleado',
      );
}

/// Cliente de /absences/*; reutiliza [LeaveException] para errores de negocio.
class AbsenceApi {
  static Future<String> _token() async =>
      (await secureStorage.readSecureData(key)) ?? '';

  static String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String evidenceUrl(String id) =>
      '$kBaseUrl/absences/justifications/$id/evidence';

  static Future<Map<String, String>> authHeaders() async =>
      {'Authorization': await _token()};

  static Future<AbsencesResult> mine() async {
    late final http.Response res;
    try {
      res = await http.get(
        Uri.parse('$kBaseUrl/absences/mine'),
        headers: {'Authorization': await _token()},
      );
    } catch (_) {
      throw LeaveException('No se pudo completar la operación debido a un error de conexión.');
    }
    _ensureOk(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return AbsencesResult(
      unjustified: ((body['unjustified'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => AbsenceRun.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      justifications: ((body['justifications'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => AbsenceJustification.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  /// Envía una justificación. La evidencia es obligatoria.
  static Future<AbsenceJustification> justify({
    required DateTime start,
    required DateTime end,
    String? reason,
    required File evidence,
  }) async {
    final req = http.MultipartRequest('POST', Uri.parse('$kBaseUrl/absences/justify'))
      ..headers['Authorization'] = await _token()
      ..fields['startDate'] = _ymd(start)
      ..fields['endDate'] = _ymd(end);
    if (reason != null && reason.trim().isNotEmpty) {
      req.fields['reason'] = reason.trim();
    }
    req.files.add(await http.MultipartFile.fromPath('evidence', evidence.path));

    late final http.StreamedResponse streamed;
    try {
      streamed = await req.send();
    } catch (_) {
      throw LeaveException('No se pudo completar la operación debido a un error de conexión.');
    }
    final res = await http.Response.fromStream(streamed);
    _ensureOk(res);
    return AbsenceJustification.fromJson(
      (jsonDecode(res.body) as Map<String, dynamic>)['justification']
          as Map<String, dynamic>,
    );
  }

  // director

  static Future<List<AdminAbsenceJustification>> adminList({String? status}) async {
    final uri = Uri.parse('$kBaseUrl/admin/absences').replace(
      queryParameters: {if (status != null && status.isNotEmpty) 'status': status},
    );
    late final http.Response res;
    try {
      res = await http.get(uri, headers: {'Authorization': await _token()});
    } catch (_) {
      throw LeaveException('No se pudo completar la operación debido a un error de conexión.');
    }
    _ensureOk(res);
    return (((jsonDecode(res.body) as Map<String, dynamic>)['justifications']
                as List?) ??
            const [])
        .whereType<Map>()
        .map((e) => AdminAbsenceJustification.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<void> adminApprove(String id, {String? note}) =>
      _adminDecide('$id/approve', note);

  static Future<void> adminReject(String id, {required String reason}) =>
      _adminDecide('$id/reject', reason);

  static Future<void> _adminDecide(String path, String? reason) async {
    late final http.Response res;
    try {
      res = await http.post(
        Uri.parse('$kBaseUrl/admin/absences/$path'),
        headers: {'Authorization': await _token()},
        body: {if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim()},
      );
    } catch (_) {
      throw LeaveException('No se pudo completar la operación debido a un error de conexión.');
    }
    _ensureOk(res);
  }

  static void _ensureOk(http.Response res) {
    if (res.statusCode == 200) return;
    String msg = 'No se pudo completar la operación. Inténtalo nuevamente.';
    try {
      final d = jsonDecode(res.body);
      if (d is Map && (d['message'] ?? d['error']) != null) {
        msg = (d['message'] ?? d['error']).toString();
      }
    } catch (_) {}
    throw LeaveException(msg);
  }
}
