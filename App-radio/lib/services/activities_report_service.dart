import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:doliv_social/core/api_config.dart';
import 'package:doliv_social/core/session_keys.dart' show secureStorage, key;
import 'package:doliv_social/services/attendance_service.dart' show AttendanceException;

/// Conteo de actividades (tareas completadas) de un empleado en el mes.
class ActivityRow {
  ActivityRow({
    required this.employeeId,
    required this.name,
    required this.position,
    required this.departmentId,
    required this.completed,
    required this.onTime,
    required this.late,
  });

  final String employeeId;
  final String name;
  final String? position;
  final String? departmentId;
  final int completed;
  final int onTime;
  final int late;

  factory ActivityRow.fromJson(Map<String, dynamic> j) => ActivityRow(
        employeeId: j['employeeId']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        position: j['position']?.toString(),
        departmentId: j['departmentId']?.toString(),
        completed: (j['completed'] as num?)?.toInt() ?? 0,
        onTime: (j['onTime'] as num?)?.toInt() ?? 0,
        late: (j['late'] as num?)?.toInt() ?? 0,
      );
}

/// Totales del reporte de actividades del mes.
class ActivityTotals {
  ActivityTotals({
    required this.completed,
    required this.onTime,
    required this.late,
    required this.people,
  });

  final int completed;
  final int onTime;
  final int late;
  final int people;

  factory ActivityTotals.fromJson(Map<String, dynamic> j) => ActivityTotals(
        completed: (j['completed'] as num?)?.toInt() ?? 0,
        onTime: (j['onTime'] as num?)?.toInt() ?? 0,
        late: (j['late'] as num?)?.toInt() ?? 0,
        people: (j['people'] as num?)?.toInt() ?? 0,
      );
}

/// Cliente de /admin/activities/* (tareas de departamento completadas en el mes).
class ActivitiesReportApi {
  static Future<String> _token() async =>
      (await secureStorage.readSecureData(key) as String?) ?? '';

  /// Vista previa: conteos por empleado + totales del mes.
  static Future<({List<ActivityRow> rows, ActivityTotals totals})> summary({
    required String month,
    String? departmentId,
  }) async {
    final uri = Uri.parse('$kBaseUrl/admin/activities/summary').replace(
      queryParameters: <String, String>{
        'month': month,
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
    if (res.statusCode != 200) {
      throw AttendanceException('No se pudo cargar el reporte de actividades.');
    }
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    return (
      rows: ((decoded['employees'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => ActivityRow.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      totals: ActivityTotals.fromJson(
          Map<String, dynamic>.from((decoded['totals'] as Map?) ?? const {})),
    );
  }

  /// Descarga el reporte detallado ([format] = `csv` | `pdf`): una fila por tarea.
  static Future<({List<int> bytes, String filename, String mime})> downloadReport({
    required String format,
    required String month,
    String? departmentId,
  }) async {
    final uri = Uri.parse('$kBaseUrl/admin/activities/report').replace(
      queryParameters: <String, String>{
        'format': format,
        'month': month,
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
    if (res.statusCode != 200) {
      throw AttendanceException('No se pudo generar el archivo.');
    }
    return (
      bytes: res.bodyBytes,
      filename: 'actividades_$month.$format',
      mime: format == 'pdf' ? 'application/pdf' : 'text/csv',
    );
  }
}
