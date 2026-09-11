import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:doliv_social/models/attendance.dart';
import 'package:doliv_social/models/calendar_event.dart';
import 'package:doliv_social/core/api_config.dart';
import 'package:doliv_social/core/device/device_identity.dart';
import 'package:doliv_social/core/session_keys.dart' show secureStorage, key;

/// Error de asistencia con mensaje en español listo para mostrar (extraído del
/// `message` del backend).
class AttendanceException implements Exception {
  AttendanceException(this.message, {this.code});
  final String message;

  /// Código de negocio opcional. `APPROVED_ABSENCE` = hay permiso aprobado hoy.
  final String? code;

  bool get isApprovedAbsence => code == 'APPROVED_ABSENCE';

  @override
  String toString() => message;
}

/// Cliente de /attendance/* y /admin/attendance|schedules.
class AttendanceApi {
  static Future<String> _token() async {
    final token = await secureStorage.readSecureData(key);
    return token ?? '';
  }

  // empleado

  /// Estado de asistencia de hoy: día, lugar configurado y, si aplica, el
  /// permiso aprobado que exime de registrar.
  static Future<
      ({
        AttendanceDay day,
        AttendanceLocationConfig? location,
        AttendanceAbsence? absence,
        EntryOverrideEvent? entryOverride,
      })> today() async {
    final res = await _get(Uri.parse('$kBaseUrl/attendance/today'));
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    return (
      day: AttendanceDay.fromJson(decoded['day'] as Map<String, dynamic>),
      location: AttendanceLocationConfig.maybe(decoded['location']),
      absence: AttendanceAbsence.maybe(decoded['absence']),
      // Evento que hoy sustituye el lugar y la hora de entrada.
      entryOverride: EntryOverrideEvent.maybe(decoded['entryOverrideEvent']),
    );
  }

  /// Ejecuta una acción de asistencia (entrada/comida/salida) y devuelve el
  /// nuevo estado del día. La ubicación es opcional (solo se valida con geocerca).
  static Future<AttendanceDay> perform(
    AttendanceAction action, {
    double? latitude,
    double? longitude,
    double? locationAccuracy,
    bool locationMocked = false,
    String method = 'gps',
    DeviceIdentity? device,
    String? biometricResult,
    String? biometricType,
  }) async {
    final res = await _post(
      Uri.parse('$kBaseUrl/${action.endpointPath}'),
      {
        'method': method,
        if (latitude != null) 'latitude': latitude.toString(),
        if (longitude != null) 'longitude': longitude.toString(),
        if (locationAccuracy != null)
          'locationAccuracy': locationAccuracy.toString(),
        'locationMocked': locationMocked ? '1' : '0',
        // Solo diagnóstico: el backend usa su propia hora como oficial.
        'deviceTime': DateTime.now().toIso8601String(),
        if (device != null) ...device.toBody(),
        if (biometricResult != null) 'biometricResult': biometricResult,
        if (biometricType != null) 'biometricType': biometricType,
      },
    );
    return AttendanceDay.fromJson(
      (jsonDecode(res.body) as Map<String, dynamic>)['day']
          as Map<String, dynamic>,
    );
  }

  /// Estado del dispositivo actual respecto de la cuenta. POST para no exponer
  /// los identificadores en la query string.
  static Future<AttendanceDeviceStatus> deviceStatus(
      DeviceIdentity device) async {
    final res = await _post(
      Uri.parse('$kBaseUrl/attendance/device/status'),
      device.toBody(),
    );
    return AttendanceDeviceStatus.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Solicita al director autorizar el dispositivo actual (bloqueado).
  static Future<AttendanceDeviceState> requestDevice(
      DeviceIdentity device) async {
    final res = await _post(
      Uri.parse('$kBaseUrl/attendance/device/request'),
      device.toBody(),
    );
    final d = jsonDecode(res.body) as Map<String, dynamic>;
    return attendanceDeviceStateFrom(d['state'] as String?);
  }

  /// Historial de asistencia del empleado (por defecto, últimos 30 días).
  static Future<List<AttendanceDay>> history(
      {DateTime? from, DateTime? to}) async {
    final uri = Uri.parse('$kBaseUrl/attendance/history').replace(
      queryParameters: <String, String>{
        if (from != null) 'from': _ymd(from),
        if (to != null) 'to': _ymd(to),
      },
    );
    final res = await _get(uri);
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    return ((decoded['days'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => AttendanceDay.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  // panel administrativo (director / manager)

  static Future<List<AdminAttendanceRow>> adminList({DateTime? date}) async {
    final uri = Uri.parse('$kBaseUrl/admin/attendance').replace(
      queryParameters: date != null ? {'date': _ymd(date)} : null,
    );
    final res = await _get(uri);
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    return ((decoded['employees'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => AdminAttendanceRow.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<List<AttendanceDay>> adminEmployeeHistory(
    String employeeId, {
    DateTime? from,
    DateTime? to,
  }) async {
    final uri = Uri.parse('$kBaseUrl/admin/attendance/$employeeId').replace(
      queryParameters: <String, String>{
        if (from != null) 'from': _ymd(from),
        if (to != null) 'to': _ymd(to),
      },
    );
    final res = await _get(uri);
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    return ((decoded['days'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => AttendanceDay.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Empleados con su horario asignado; `canEdit` solo para director.
  static Future<({List<EmployeeScheduleRow> rows, bool canEdit})>
      adminSchedules() async {
    final res = await _get(Uri.parse('$kBaseUrl/admin/schedules'));
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final rows = ((decoded['employees'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => EmployeeScheduleRow.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return (rows: rows, canEdit: decoded['canEdit'] == true);
  }

  /// Lugar de asistencia configurado (director y manager pueden leerlo).
  static Future<({AttendanceLocationConfig? location, bool canEdit})>
      adminLocation() async {
    final res = await _get(Uri.parse('$kBaseUrl/admin/attendance-location'));
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    return (
      location: AttendanceLocationConfig.maybe(decoded['location']),
      canEdit: decoded['canEdit'] == true,
    );
  }

  /// Define o mueve el lugar de asistencia (solo director).
  static Future<AttendanceLocationConfig> saveLocation({
    required double latitude,
    required double longitude,
    required int radiusM,
    String? label,
  }) async {
    final res = await _post(
      Uri.parse('$kBaseUrl/admin/attendance-location'),
      {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'radiusM': radiusM.toString(),
        if (label != null && label.trim().isNotEmpty) 'label': label.trim(),
      },
    );
    return AttendanceLocationConfig.fromJson(
      (jsonDecode(res.body) as Map<String, dynamic>)['location']
          as Map<String, dynamic>,
    );
  }

  /// Crea o modifica el horario de un empleado (solo director).
  static Future<EmployeeSchedule> saveSchedule(
    String employeeId, {
    required String entryTime,
    required String exitTime,
    required String mealTime,
    required int mealMaxMinutes,
    required int lateToleranceMinutes,
  }) async {
    final res = await _post(
      Uri.parse('$kBaseUrl/admin/schedules/$employeeId'),
      {
        'entryTime': entryTime,
        'exitTime': exitTime,
        'mealTime': mealTime,
        'mealMaxMinutes': mealMaxMinutes.toString(),
        'lateToleranceMinutes': lateToleranceMinutes.toString(),
      },
    );
    return EmployeeSchedule.fromJson(
      (jsonDecode(res.body) as Map<String, dynamic>)['schedule']
          as Map<String, dynamic>,
    );
  }

  /// Asigna el mismo horario a varios trabajadores (solo director). Devuelve
  /// cuántos se aplicaron y los ids que fallaron.
  static Future<({int applied, List<String> failed, String message})>
      bulkSaveSchedule({
    required List<String> employeeIds,
    required String entryTime,
    required String exitTime,
    required String mealTime,
    required int mealMaxMinutes,
    required int lateToleranceMinutes,
  }) async {
    final res = await _post(
      Uri.parse('$kBaseUrl/admin/schedules/bulk'),
      {
        'employeeIds': employeeIds.join(','),
        'entryTime': entryTime,
        'exitTime': exitTime,
        'mealTime': mealTime,
        'mealMaxMinutes': mealMaxMinutes.toString(),
        'lateToleranceMinutes': lateToleranceMinutes.toString(),
      },
    );
    final d = jsonDecode(res.body) as Map<String, dynamic>;
    return (
      applied: (d['appliedCount'] as num?)?.toInt() ?? 0,
      failed: ((d['failed'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      message: d['message']?.toString() ?? 'Horarios asignados.',
    );
  }

  // dispositivos (panel administrativo)

  static Future<List<DeviceRequestRow>> adminDeviceRequests(
      {String status = 'pending'}) async {
    final uri = Uri.parse('$kBaseUrl/admin/attendance/device-requests')
        .replace(queryParameters: {'status': status});
    final res = await _get(uri);
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    return ((decoded['requests'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => DeviceRequestRow.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<void> resolveDeviceRequest(int id,
      {required bool approve, String? note}) async {
    await _post(
      Uri.parse('$kBaseUrl/admin/attendance/device-requests/$id/resolve'),
      {
        'decision': approve ? 'approve' : 'reject',
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
  }

  static Future<List<DeviceAnomaly>> adminDeviceAnomalies(
      {int days = 30}) async {
    final uri = Uri.parse('$kBaseUrl/admin/attendance/device-anomalies')
        .replace(queryParameters: {'days': days.toString()});
    final res = await _get(uri);
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    return ((decoded['anomalies'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => DeviceAnomaly.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Dispositivo vinculado de cada empleado (pestaña "Dispositivos").
  static Future<List<TrustedDeviceRow>> adminTrustedDevices() async {
    final res =
        await _get(Uri.parse('$kBaseUrl/admin/attendance/trusted-devices'));
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    return ((decoded['devices'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => TrustedDeviceRow.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<TrustedDeviceInfo?> adminEmployeeDevice(
      String employeeId) async {
    final res =
        await _get(Uri.parse('$kBaseUrl/admin/attendance/$employeeId/device'));
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final d = decoded['device'];
    return d is Map
        ? TrustedDeviceInfo.fromJson(Map<String, dynamic>.from(d))
        : null;
  }

  static Future<void> adminResetEmployeeDevice(String employeeId) async {
    await _post(
        Uri.parse('$kBaseUrl/admin/attendance/$employeeId/device/reset'), {});
  }

  // resumen mensual

  /// Resumen de asistencia del mes ([month] = `YYYY-MM`, por defecto el actual).
  static Future<AttendancePeriodSummary> summary({String? month}) async {
    final uri = Uri.parse('$kBaseUrl/attendance/summary').replace(
      queryParameters: month != null ? {'month': month} : null,
    );
    final res = await _get(uri);
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    return AttendancePeriodSummary.fromJson(
        decoded['summary'] as Map<String, dynamic>);
  }

  /// Resumen mensual por empleado + totales (director / manager).
  static Future<
      ({
        List<AdminAttendanceSummaryRow> rows,
        AttendancePeriodSummary totals
      })> adminSummary({String? month, String? departmentId}) async {
    final uri = Uri.parse('$kBaseUrl/admin/attendance/summary').replace(
      queryParameters: <String, String>{
        if (month != null) 'month': month,
        if (departmentId != null && departmentId.isNotEmpty)
          'departmentId': departmentId,
      },
    );
    final res = await _get(uri);
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final rows = ((decoded['employees'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) =>
            AdminAttendanceSummaryRow.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return (
      rows: rows,
      totals: AttendancePeriodSummary.fromJson(
          Map<String, dynamic>.from((decoded['totals'] as Map?) ?? const {})),
    );
  }

  /// Descarga el reporte mensual ([format] = `csv` | `pdf`).
  static Future<({List<int> bytes, String filename, String mime})>
      downloadReport({
    required String format,
    String? month,
    String? departmentId,
  }) async {
    final uri = Uri.parse('$kBaseUrl/admin/attendance/report').replace(
      queryParameters: <String, String>{
        'format': format,
        if (month != null) 'month': month,
        if (departmentId != null && departmentId.isNotEmpty)
          'departmentId': departmentId,
      },
    );
    late final http.Response res;
    try {
      res = await http.get(uri, headers: {'Authorization': await _token()});
    } catch (_) {
      throw AttendanceException(
          'Se produjo un error de conexión. Inténtalo nuevamente.');
    }
    if (res.statusCode != 200) _ensureOk(res);
    final m = (month ?? DateTime.now().toIso8601String().substring(0, 7));
    return (
      bytes: res.bodyBytes,
      filename: 'asistencia_$m.$format',
      mime: format == 'pdf' ? 'application/pdf' : 'text/csv',
    );
  }

  // solicitudes de corrección

  static Future<AttendanceCorrection> createCorrection({
    required DateTime workDate,
    required CorrectionKind kind,
    required String requestedTime, // HH:MM
    required String reason,
  }) async {
    final res = await _post(Uri.parse('$kBaseUrl/attendance/corrections'), {
      'workDate': _ymd(workDate),
      'kind': kind.apiValue,
      'requestedTime': requestedTime,
      'reason': reason.trim(),
    });
    return AttendanceCorrection.fromJson((jsonDecode(res.body)
        as Map<String, dynamic>)['request'] as Map<String, dynamic>);
  }

  static Future<List<AttendanceCorrection>> myCorrections() async {
    final res = await _get(Uri.parse('$kBaseUrl/attendance/corrections/my'));
    return _correctionList(res);
  }

  static Future<List<AttendanceCorrection>> adminCorrections(
      {CorrectionStatus? status}) async {
    final uri = Uri.parse('$kBaseUrl/admin/attendance/corrections').replace(
      queryParameters: status != null ? {'status': status.apiValue} : null,
    );
    final res = await _get(uri);
    return _correctionList(res);
  }

  static Future<AttendanceCorrection> resolveCorrection(
    int id, {
    required bool approve,
    String? note,
  }) async {
    final res = await _post(
      Uri.parse('$kBaseUrl/admin/attendance/corrections/$id/resolve'),
      {
        'decision': approve ? 'approve' : 'reject',
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
    return AttendanceCorrection.fromJson((jsonDecode(res.body)
        as Map<String, dynamic>)['request'] as Map<String, dynamic>);
  }

  static List<AttendanceCorrection> _correctionList(http.Response res) {
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    return ((decoded['requests'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => AttendanceCorrection.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  // transporte

  static String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static Future<http.Response> _get(Uri uri) async {
    late final http.Response res;
    try {
      res = await http.get(uri, headers: {'Authorization': await _token()});
    } catch (_) {
      throw AttendanceException(
          'Se produjo un error de conexión. Inténtalo nuevamente.');
    }
    _ensureOk(res);
    return res;
  }

  static Future<http.Response> _post(Uri uri, Map<String, String> body) async {
    late final http.Response res;
    try {
      res = await http.post(uri,
          headers: {'Authorization': await _token()}, body: body);
    } catch (_) {
      throw AttendanceException(
          'Se produjo un error de conexión. Inténtalo nuevamente.');
    }
    _ensureOk(res);
    return res;
  }

  static void _ensureOk(http.Response res) {
    if (res.statusCode == 200) return;
    String? code;
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map && decoded['code'] != null) {
        code = decoded['code'].toString();
      }
    } catch (_) {}
    throw AttendanceException(_extractMessage(res.body), code: code);
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
