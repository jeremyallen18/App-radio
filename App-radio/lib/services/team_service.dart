import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'package:doliv_social/models/dept_task.dart';
import 'package:doliv_social/models/models.dart';
import 'package:doliv_social/core/api_config.dart';
import 'package:doliv_social/core/session_keys.dart' show secureStorage, key;

/// Error de la gestión de equipos/tareas, con mensaje en español listo para
/// mostrar. El backend responde `{success:false, message}` o `{error}`.
class TeamException implements Exception {
  TeamException(this.message);
  final String message;

  @override
  String toString() => message;
}

Future<String> _token() async {
  final t = await secureStorage.readSecureData(key);
  return (t as String?) ?? '';
}

Future<http.Response> _get(Uri uri) async {
  late final http.Response res;
  try {
    res = await http.get(uri, headers: {'Authorization': await _token()});
  } catch (_) {
    throw TeamException('No se pudo completar la operación debido a un error de conexión.');
  }
  _ensureOk(res);
  return res;
}

Future<http.Response> _post(Uri uri, Map<String, String> body) async {
  late final http.Response res;
  try {
    res = await http.post(uri, headers: {'Authorization': await _token()}, body: body);
  } catch (_) {
    throw TeamException('No se pudo completar la operación debido a un error de conexión.');
  }
  _ensureOk(res);
  return res;
}

void _ensureOk(http.Response res) {
  if (res.statusCode == 200) return;
  String msg = 'No se pudo completar la operación. Inténtalo nuevamente.';
  try {
    final d = jsonDecode(res.body);
    if (d is Map && (d['message'] ?? d['error']) != null) {
      msg = (d['message'] ?? d['error']).toString();
    }
  } catch (_) {}
  throw TeamException(msg);
}

Map<String, dynamic> _body(http.Response res) => jsonDecode(res.body) as Map<String, dynamic>;

/// Equipos = departamentos: crear, asignar manager y miembros (solo director;
/// el manager también puede agregar/quitar empleados de SU departamento).
class TeamApi {
  static Future<List<DepartmentInfo>> listDepartments() async {
    final res = await _get(Uri.parse('$kBaseUrl/department/list'));
    return ((_body(res)['departments'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => DepartmentInfo.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<DepartmentInfo> createDepartment({
    required String name,
    String? description,
  }) async {
    final res = await _post(Uri.parse('$kBaseUrl/department/create'), {
      'name': name.trim(),
      if (description != null && description.trim().isNotEmpty) 'description': description.trim(),
    });
    return DepartmentInfo.fromJson(_body(res)['department'] as Map<String, dynamic>);
  }

  static Future<DepartmentInfo> assignManager(String deptId, {required String email}) async {
    final res = await _post(
      Uri.parse('$kBaseUrl/department/assignManager/$deptId'),
      {'email': email.trim()},
    );
    return DepartmentInfo.fromJson(_body(res)['department'] as Map<String, dynamic>);
  }

  static Future<DepartmentInfo> addEmployee(
    String deptId, {
    required String email,
    String? position,
  }) async {
    final res = await _post(
      Uri.parse('$kBaseUrl/department/assignEmployee/$deptId'),
      {
        'email': email.trim(),
        if (position != null && position.trim().isNotEmpty) 'position': position.trim(),
      },
    );
    return DepartmentInfo.fromJson(_body(res)['department'] as Map<String, dynamic>);
  }

  static Future<void> removeEmployee(String deptId, {required String email}) async {
    await _post(
      Uri.parse('$kBaseUrl/department/removeEmployee/$deptId'),
      {'email': email.trim()},
    );
  }

  /// Miembros de un departamento (usa el directorio interno con scope = id).
  static Future<List<UserProfile>> members(String deptId) async {
    final uri = Uri.parse('$kBaseUrl/user/directory')
        .replace(queryParameters: {'scope': deptId});
    final res = await _get(uri);
    return ((_body(res)['colleagues'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => UserProfile.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Toda la gente de la empresa (para elegir manager / agregar empleado).
  static Future<List<UserProfile>> allPeople({String query = ''}) async {
    final uri = Uri.parse('$kBaseUrl/user/directory').replace(queryParameters: {
      'scope': 'company',
      if (query.trim().isNotEmpty) 'q': query.trim(),
    });
    final res = await _get(uri);
    return ((_body(res)['colleagues'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => UserProfile.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}

/// Tareas jerárquicas por departamento.
class DeptTaskApi {
  static Future<List<DeptTask>> list({
    String? departmentId,
    DeptTaskStatus? status,
    bool mine = false,
  }) async {
    final uri = Uri.parse('$kBaseUrl/dept-tasks').replace(queryParameters: <String, String>{
      if (departmentId != null && departmentId.isNotEmpty) 'departmentId': departmentId,
      if (status != null) 'status': status.apiValue,
      if (mine) 'mine': '1',
    });
    final res = await _get(uri);
    return ((_body(res)['tasks'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => DeptTask.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<DeptTask> create({
    String? departmentId,
    required String title,
    String? description,
    String? assignedTo,
    DateTime? dueDate,
    String? parentId,
    bool requiresEvidence = false,
    TaskRecurrence recurrence = TaskRecurrence.none,
    DateTime? recurrenceUntil,
  }) async {
    final res = await _post(Uri.parse('$kBaseUrl/dept-tasks'), {
      if (departmentId != null && departmentId.isNotEmpty) 'departmentId': departmentId,
      'title': title.trim(),
      if (description != null && description.trim().isNotEmpty) 'description': description.trim(),
      if (assignedTo != null && assignedTo.isNotEmpty) 'assignedTo': assignedTo,
      if (dueDate != null) 'dueDate': _ymd(dueDate),
      if (parentId != null && parentId.isNotEmpty) 'parentId': parentId,
      'requiresEvidence': requiresEvidence ? '1' : '0',
      'recurrence': recurrence.apiValue,
      if (recurrence != TaskRecurrence.none && recurrenceUntil != null)
        'recurrenceUntil': _ymd(recurrenceUntil),
    });
    return DeptTask.fromJson(_body(res)['task'] as Map<String, dynamic>);
  }

  static Future<DeptTask> update(
    String id, {
    String? title,
    String? description,
    String? assignedTo,
    bool clearAssignee = false,
    DateTime? dueDate,
    bool clearDueDate = false,
    bool? requiresEvidence,
    TaskRecurrence? recurrence,
    DateTime? recurrenceUntil,
  }) async {
    final res = await _post(Uri.parse('$kBaseUrl/dept-tasks/$id'), {
      if (title != null) 'title': title.trim(),
      if (description != null) 'description': description.trim(),
      if (clearAssignee) 'assignedTo': '' else if (assignedTo != null) 'assignedTo': assignedTo,
      if (clearDueDate) 'dueDate': '' else if (dueDate != null) 'dueDate': _ymd(dueDate),
      if (requiresEvidence != null) 'requiresEvidence': requiresEvidence ? '1' : '0',
      if (recurrence != null) 'recurrence': recurrence.apiValue,
      if (recurrence != null)
        'recurrenceUntil': (recurrence != TaskRecurrence.none && recurrenceUntil != null)
            ? _ymd(recurrenceUntil)
            : '',
    });
    return DeptTask.fromJson(_body(res)['task'] as Map<String, dynamic>);
  }

  static Future<DeptTask> setStatus(String id, DeptTaskStatus status) async {
    final res = await _post(
      Uri.parse('$kBaseUrl/dept-tasks/$id/status'),
      {'status': status.apiValue},
    );
    return DeptTask.fromJson(_body(res)['task'] as Map<String, dynamic>);
  }

  /// Marca la tarea como completada. Si [evidence] no es null, la sube como
  /// `multipart/form-data` (para tareas con `requiresEvidence`).
  static Future<DeptTask> complete(String id, {File? evidence}) async {
    if (evidence == null) {
      return setStatus(id, DeptTaskStatus.completada);
    }
    final req = http.MultipartRequest(
      'POST',
      Uri.parse('$kBaseUrl/dept-tasks/$id/status'),
    )
      ..headers['Authorization'] = await _token()
      ..fields['status'] = 'completada'
      ..files.add(await http.MultipartFile.fromPath('evidence', evidence.path));
    late final http.Response res;
    try {
      res = await http.Response.fromStream(await req.send());
    } catch (_) {
      throw TeamException(
          'No se pudo completar la operación debido a un error de conexión.');
    }
    _ensureOk(res);
    return DeptTask.fromJson(_body(res)['task'] as Map<String, dynamic>);
  }

  /// Aprueba o devuelve (rechaza) una tarea pendiente de revisión.
  static Future<DeptTask> review(
    String id, {
    required bool approve,
    String? note,
  }) async {
    final res = await _post(Uri.parse('$kBaseUrl/dept-tasks/$id/review'), {
      'decision': approve ? 'approve' : 'reject',
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    });
    return DeptTask.fromJson(_body(res)['task'] as Map<String, dynamic>);
  }

  static Future<List<TaskComment>> comments(String id) async {
    final res = await _get(Uri.parse('$kBaseUrl/dept-tasks/$id/comments'));
    return ((_body(res)['comments'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => TaskComment.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<TaskComment> addComment(String id, String body) async {
    final res = await _post(
      Uri.parse('$kBaseUrl/dept-tasks/$id/comments'),
      {'body': body.trim()},
    );
    return TaskComment.fromJson(_body(res)['comment'] as Map<String, dynamic>);
  }

  /// URL del archivo de evidencia (endpoint autenticado). Úsala con
  /// [evidenceHeaders] en un `Image.network` o en el visor.
  static String evidenceUrl(String id) => '$kBaseUrl/dept-tasks/$id/evidence';

  static Future<Map<String, String>> evidenceHeaders() async =>
      {'Authorization': await _token()};

  static Future<void> delete(String id) async {
    await _post(Uri.parse('$kBaseUrl/dept-tasks/$id/delete'), {});
  }

  /// Conteos para las gráficas de progreso: `mine` (asignadas a mí) y
  /// `dept` (todas las de mi departamento; `hasDept` es false para un
  /// director sin departamento).
  static Future<
      ({
        int minePending,
        int mineDone,
        int mineTotal,
        int deptPending,
        int deptDone,
        int deptTotal,
        bool hasDept,
      })> summary() async {
    final res = await _get(Uri.parse('$kBaseUrl/dept-tasks/summary'));
    final b = _body(res);
    final m = (b['mine'] as Map?) ?? const {};
    final d = b['department'] as Map?;
    int n(Map? map, String k) => (map?[k] as num?)?.toInt() ?? 0;
    return (
      minePending: n(m, 'pendientes'),
      mineDone: n(m, 'completada'),
      mineTotal: n(m, 'total'),
      deptPending: n(d, 'pendientes'),
      deptDone: n(d, 'completada'),
      deptTotal: n(d, 'total'),
      hasDept: d != null,
    );
  }

  /// Conteos de tareas por estado para CADA departamento de la empresa,
  /// más los totales. Solo el director tiene acceso: el backend responde
  /// 403 a cualquier otro rol. Alimenta las gráficas de desempeño por
  /// departamento del panel del director.
  static Future<DeptTasksByDepartment> summaryByDepartment() async {
    final res = await _get(Uri.parse('$kBaseUrl/dept-tasks/summary/by-department'));
    final b = _body(res);
    int n(Map? map, String k) => (map?[k] as num?)?.toInt() ?? 0;
    final rows = ((b['departments'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => DepartmentTaskCounts(
              departmentId: (e['departmentId'] ?? '').toString(),
              departmentName: (e['departmentName'] ?? '').toString(),
              pending: n(e, 'pendientes'),
              done: n(e, 'completada'),
              total: n(e, 'total'),
            ))
        .toList();
    final t = b['totals'] as Map?;
    return DeptTasksByDepartment(
      departments: rows,
      totalPending: n(t, 'pendientes'),
      totalDone: n(t, 'completada'),
      total: n(t, 'total'),
    );
  }

  static String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// Avance de tareas de un departamento (para las gráficas del director).
/// `pending` incluye las tareas en progreso, igual que el resto de la app.
class DepartmentTaskCounts {
  const DepartmentTaskCounts({
    required this.departmentId,
    required this.departmentName,
    required this.pending,
    required this.done,
    required this.total,
  });

  final String departmentId;
  final String departmentName;
  final int pending;
  final int done;
  final int total;

  /// Fracción completada 0..1 (0 cuando el departamento no tiene tareas).
  double get completionRatio => total == 0 ? 0 : done / total;
}

/// Respuesta de [DeptTaskApi.summaryByDepartment]: una fila por
/// departamento más los totales de toda la empresa.
class DeptTasksByDepartment {
  const DeptTasksByDepartment({
    required this.departments,
    required this.totalPending,
    required this.totalDone,
    required this.total,
  });

  final List<DepartmentTaskCounts> departments;
  final int totalPending;
  final int totalDone;
  final int total;

  double get completionRatio => total == 0 ? 0 : totalDone / total;
}
