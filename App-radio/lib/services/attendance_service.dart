import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:doliv_social/models/attendance.dart';
import 'package:doliv_social/models/calendar_event.dart';
import 'package:doliv_social/core/api_config.dart';
import 'package:doliv_social/core/session_keys.dart' show secureStorage, key;

/// Error del módulo de asistencia con un mensaje ya listo para mostrar en
/// español. El backend responde `{success:false, message:"..."}` en los
/// errores de negocio (estado inválido, director, fuera de zona); aquí solo
/// se extrae ese `message`. Nunca se exponen detalles técnicos.
class AttendanceException implements Exception {
  AttendanceException(this.message, {this.code});
  final String message;

  /// Código de negocio opcional del backend. `APPROVED_ABSENCE` = el
  /// trabajador tiene un permiso aprobado para hoy y no debe registrar.
  final String? code;

  bool get isApprovedAbsence => code == 'APPROVED_ABSENCE';

  @override
  String toString() => message;
}

/// Cliente de /attendance/* y /admin/attendance|schedules (hive-backend).
/// Mismo patrón que `directory_api.dart`.
class AttendanceApi {
  static Future<String> _token() async {
    final token = await secureStorage.readSecureData(key);
    return (token as String?) ?? '';
  }

  // ---- empleado ---------------------------------------------------

  /// Estado de asistencia de hoy del trabajador autenticado: el día, el lugar
  /// de asistencia configurado por el director, y —si aplica— el permiso
  /// aprobado que hace que hoy NO se requiera registrar asistencia.
  static Future<({
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
      // Evento con ubicación que hoy sustituye el lugar y la hora de ENTRADA.
      entryOverride: EntryOverrideEvent.maybe(decoded['entryOverrideEvent']),
    );
  }

  /// Ejecuta la acción de asistencia indicada (entrada / comida / salida) y
  /// devuelve el nuevo estado del día. La ubicación es opcional: el backend
  /// solo la valida si la geocerca está activada.
  static Future<AttendanceDay> perform(
    AttendanceAction action, {
    double? latitude,
    double? longitude,
    String method = 'gps',
  }) async {
    final res = await _post(
      Uri.parse('$kBaseUrl/${action.endpointPath}'),
      {
        'method': method,
        if (latitude != null) 'latitude': latitude.toString(),
        if (longitude != null) 'longitude': longitude.toString(),
        // Solo diagnóstico: el backend usa su propia hora como oficial.
        'deviceTime': DateTime.now().toIso8601String(),
      },
    );
    return AttendanceDay.fromJson(
      (jsonDecode(res.body) as Map<String, dynamic>)['day'] as Map<String, dynamic>,
    );
  }

  /// Historial de asistencia del empleado (por defecto, últimos 30 días).
  static Future<List<AttendanceDay>> history({DateTime? from, DateTime? to}) async {
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

  // ---- panel administrativo (director / manager) ----------------

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

  /// Lista de empleados con su horario asignado (o `null` si no tiene). El
  /// segundo valor indica si el usuario actual puede editar (solo director).
  static Future<({List<EmployeeScheduleRow> rows, bool canEdit})> adminSchedules() async {
    final res = await _get(Uri.parse('$kBaseUrl/admin/schedules'));
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final rows = ((decoded['employees'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => EmployeeScheduleRow.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return (rows: rows, canEdit: decoded['canEdit'] == true);
  }

  /// Lugar de asistencia configurado (director y manager pueden leerlo).
  static Future<({AttendanceLocationConfig? location, bool canEdit})> adminLocation() async {
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
      (jsonDecode(res.body) as Map<String, dynamic>)['location'] as Map<String, dynamic>,
    );
  }

  /// Crea o modifica el horario de un empleado (solo director). No altera el
  /// histórico ya registrado.
  static Future<EmployeeSchedule> saveSchedule(
    String employeeId, {
    required String entryTime,
    required String exitTime,
    required String mealTime,
    required int mealMaxMinutes,
  }) async {
    final res = await _post(
      Uri.parse('$kBaseUrl/admin/schedules/$employeeId'),
      {
        'entryTime': entryTime,
        'exitTime': exitTime,
        'mealTime': mealTime,
        'mealMaxMinutes': mealMaxMinutes.toString(),
      },
    );
    return EmployeeSchedule.fromJson(
      (jsonDecode(res.body) as Map<String, dynamic>)['schedule'] as Map<String, dynamic>,
    );
  }

  // ---- resumen mensual ----------------------------------------------

  /// Resumen de asistencia del mes ([month] = `YYYY-MM`, por defecto el mes
  /// en curso) del trabajador autenticado.
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
  static Future<({List<AdminAttendanceSummaryRow> rows, AttendancePeriodSummary totals})>
      adminSummary({String? month, String? departmentId}) async {
    final uri = Uri.parse('$kBaseUrl/admin/attendance/summary').replace(
      queryParameters: <String, String>{
        if (month != null) 'month': month,
        if (departmentId != null && departmentId.isNotEmpty) 'departmentId': departmentId,
      },
    );
    final res = await _get(uri);
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final rows = ((decoded['employees'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => AdminAttendanceSummaryRow.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return (
      rows: rows,
      totals: AttendancePeriodSummary.fromJson(
          Map<String, dynamic>.from((decoded['totals'] as Map?) ?? const {})),
    );
  }

  /// Descarga el reporte mensual y devuelve `(bytes, filename, mime)`.
  /// [format] = `csv` | `pdf`.
  static Future<({List<int> bytes, String filename, String mime})> downloadReport({
    required String format,
    String? month,
    String? departmentId,
  }) async {
    final uri = Uri.parse('$kBaseUrl/admin/attendance/report').replace(
      queryParameters: <String, String>{
        'format': format,
        if (month != null) 'month': month,
        if (departmentId != null && departmentId.isNotEmpty) 'departmentId': departmentId,
      },
    );
    late final http.Response res;
    try {
      res = await http.get(uri, headers: {'Authorization': await _token()});
    } catch (_) {
      throw AttendanceException('Se produjo un error de conexión. Inténtalo nuevamente.');
    }
    if (res.statusCode != 200) _ensureOk(res);
    final m = (month ?? DateTime.now().toIso8601String().substring(0, 7));
    return (
      bytes: res.bodyBytes,
      filename: 'asistencia_$m.$format',
      mime: format == 'pdf' ? 'application/pdf' : 'text/csv',
    );
  }

  // ---- solicitudes de corrección ----------------------------------

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
    return AttendanceCorrection.fromJson(
        (jsonDecode(res.body) as Map<String, dynamic>)['request'] as Map<String, dynamic>);
  }

  static Future<List<AttendanceCorrection>> myCorrections() async {
    final res = await _get(Uri.parse('$kBaseUrl/attendance/corrections/my'));
    return _correctionList(res);
  }

  static Future<List<AttendanceCorrection>> adminCorrections({CorrectionStatus? status}) async {
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
    return AttendanceCorrection.fromJson(
        (jsonDecode(res.body) as Map<String, dynamic>)['request'] as Map<String, dynamic>);
  }

  static List<AttendanceCorrection> _correctionList(http.Response res) {
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    return ((decoded['requests'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => AttendanceCorrection.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  // ---- transporte -----------------------------------------------

  static String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static Future<http.Response> _get(Uri uri) async {
    late final http.Response res;
    try {
      res = await http.get(uri, headers: {'Authorization': await _token()});
    } catch (_) {
      throw AttendanceException('Se produjo un error de conexión. Inténtalo nuevamente.');
    }
    _ensureOk(res);
    return res;
  }

  static Future<http.Response> _post(Uri uri, Map<String, String> body) async {
    late final http.Response res;
    try {
      res = await http.post(uri, headers: {'Authorization': await _token()}, body: body);
    } catch (_) {
      throw AttendanceException('Se produjo un error de conexión. Inténtalo nuevamente.');
    }
    _ensureOk(res);
    return res;
  }

  static void _ensureOk(http.Response res) {
    if (res.statusCode == 200) return;
    String? code;
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map && decoded['code'] != null) code = decoded['code'].toString();
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
