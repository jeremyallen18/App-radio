// Modelos del módulo de asistencia y hora de comida (Radio Doliv). Alimentados
// por los endpoints /attendance/* y /admin/attendance|schedules del backend
// PHP (hive-backend/attendance.php). Todos los cálculos vienen resueltos del
// servidor; aquí solo se transportan y se muestran.

/// Estado del ciclo de asistencia del día. Lo determina el backend a partir
/// de los eventos inmutables; el cliente nunca lo infiere por su cuenta.
enum AttendanceState { sinEntrada, enJornada, enComida, jornadaTerminada }

AttendanceState attendanceStateFromString(String? value) {
  switch (value) {
    case 'en_jornada':
      return AttendanceState.enJornada;
    case 'en_comida':
      return AttendanceState.enComida;
    case 'jornada_terminada':
      return AttendanceState.jornadaTerminada;
    default:
      return AttendanceState.sinEntrada;
  }
}

/// Acción que el empleado puede realizar ahora mismo (la que dicta el botón
/// principal). `null` cuando la jornada ya terminó.
enum AttendanceAction { entrada, inicioComida, finComida, salida }

AttendanceAction? attendanceActionFromString(String? value) {
  switch (value) {
    case 'entrada':
      return AttendanceAction.entrada;
    case 'inicio_comida':
      return AttendanceAction.inicioComida;
    case 'fin_comida':
      return AttendanceAction.finComida;
    case 'salida':
      return AttendanceAction.salida;
    default:
      return null;
  }
}

extension AttendanceActionInfo on AttendanceAction {
  /// Texto del botón principal (requisito: 100% en español).
  String get buttonLabel {
    switch (this) {
      case AttendanceAction.entrada:
        return 'REGISTRAR ENTRADA';
      case AttendanceAction.inicioComida:
        return 'INICIAR HORA DE COMIDA';
      case AttendanceAction.finComida:
        return 'TERMINAR HORA DE COMIDA';
      case AttendanceAction.salida:
        return 'REGISTRAR SALIDA';
    }
  }

  /// Segmento de ruta del endpoint POST correspondiente.
  String get endpointPath {
    switch (this) {
      case AttendanceAction.entrada:
        return 'attendance/entry';
      case AttendanceAction.inicioComida:
        return 'attendance/meal/start';
      case AttendanceAction.finComida:
        return 'attendance/meal/end';
      case AttendanceAction.salida:
        return 'attendance/exit';
    }
  }
}

/// Permiso aprobado que cubre el día de hoy: la asistencia no se requiere.
/// Lo devuelve GET /attendance/today (campo `absence`).
class AttendanceAbsence {
  final String type;      // vacaciones | incapacidad | permiso
  final String typeLabel; // etiqueta en español
  final DateTime? startDate;
  final DateTime? endDate;

  AttendanceAbsence({
    required this.type,
    required this.typeLabel,
    required this.startDate,
    required this.endDate,
  });

  factory AttendanceAbsence.fromJson(Map<String, dynamic> json) => AttendanceAbsence(
        type: json['type']?.toString() ?? '',
        typeLabel: json['typeLabel']?.toString() ?? 'Ausencia autorizada',
        startDate: DateTime.tryParse(json['startDate']?.toString() ?? ''),
        endDate: DateTime.tryParse(json['endDate']?.toString() ?? ''),
      );

  static AttendanceAbsence? maybe(dynamic json) {
    if (json is Map) {
      return AttendanceAbsence.fromJson(Map<String, dynamic>.from(json));
    }
    return null;
  }

  String get rangeLabel {
    final s = startDate, e = endDate;
    if (s == null || e == null) return '';
    String f(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    return s == e ? f(s) : '${f(s)} → ${f(e)}';
  }
}

/// Lugar de asistencia configurado por el director (geocerca). `entrada` y
/// `fin_comida` se rechazan si el GPS del trabajador cae fuera del radio.
class AttendanceLocationConfig {
  final double latitude;
  final double longitude;
  final int radiusM;
  final String? label;

  AttendanceLocationConfig({
    required this.latitude,
    required this.longitude,
    required this.radiusM,
    this.label,
  });

  factory AttendanceLocationConfig.fromJson(Map<String, dynamic> json) {
    return AttendanceLocationConfig(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      radiusM: (json['radiusM'] as num?)?.toInt() ?? 10,
      label: json['label'] as String?,
    );
  }

  static AttendanceLocationConfig? maybe(dynamic json) {
    if (json is Map) {
      return AttendanceLocationConfig.fromJson(Map<String, dynamic>.from(json));
    }
    return null;
  }
}

/// Horario asignado a un empleado por el director.
class EmployeeSchedule {
  final String entryTime; // "HH:MM"
  final String exitTime;
  final String mealTime;
  final int mealMaxMinutes;

  EmployeeSchedule({
    required this.entryTime,
    required this.exitTime,
    required this.mealTime,
    required this.mealMaxMinutes,
  });

  factory EmployeeSchedule.fromJson(Map<String, dynamic> json) {
    return EmployeeSchedule(
      entryTime: json['entryTime']?.toString() ?? '--:--',
      exitTime: json['exitTime']?.toString() ?? '--:--',
      mealTime: json['mealTime']?.toString() ?? '--:--',
      mealMaxMinutes: (json['mealMaxMinutes'] as num?)?.toInt() ?? 60,
    );
  }
}

/// Resumen de un día de asistencia: horas registradas + cálculos del backend.
class AttendanceDay {
  final DateTime? workDate;
  final AttendanceState state;
  final String stateLabel;
  final AttendanceAction? nextAction;

  final String? entrada; // "HH:MM" o null
  final String? inicioComida;
  final String? finComida;
  final String? salida;

  final int? mealMinutes;
  final String? mealMinutesLabel;
  final int? mealElapsedMinutes; // comida en curso (para el temporizador)

  final int? workedMinutes;
  final String? workedLabel;
  final bool workedInProgress;

  final bool isLate;
  final int lateMinutes;

  final int? mealLimitMinutes;
  final bool mealExceeded;
  final int mealExcessMinutes;

  final EmployeeSchedule? schedule;

  AttendanceDay({
    required this.workDate,
    required this.state,
    required this.stateLabel,
    required this.nextAction,
    required this.entrada,
    required this.inicioComida,
    required this.finComida,
    required this.salida,
    required this.mealMinutes,
    required this.mealMinutesLabel,
    required this.mealElapsedMinutes,
    required this.workedMinutes,
    required this.workedLabel,
    required this.workedInProgress,
    required this.isLate,
    required this.lateMinutes,
    required this.mealLimitMinutes,
    required this.mealExceeded,
    required this.mealExcessMinutes,
    required this.schedule,
  });

  factory AttendanceDay.fromJson(Map<String, dynamic> json) {
    final schedJson = json['schedule'];
    return AttendanceDay(
      workDate: DateTime.tryParse(json['workDate']?.toString() ?? ''),
      state: attendanceStateFromString(json['state']?.toString()),
      stateLabel: json['stateLabel']?.toString() ?? 'Sin entrada',
      nextAction: attendanceActionFromString(json['nextAction']?.toString()),
      entrada: json['entrada']?.toString(),
      inicioComida: json['inicioComida']?.toString(),
      finComida: json['finComida']?.toString(),
      salida: json['salida']?.toString(),
      mealMinutes: (json['mealMinutes'] as num?)?.toInt(),
      mealMinutesLabel: json['mealMinutesLabel']?.toString(),
      mealElapsedMinutes: (json['mealElapsedMinutes'] as num?)?.toInt(),
      workedMinutes: (json['workedMinutes'] as num?)?.toInt(),
      workedLabel: json['workedLabel']?.toString(),
      workedInProgress: json['workedInProgress'] == true,
      isLate: json['isLate'] == true,
      lateMinutes: (json['lateMinutes'] as num?)?.toInt() ?? 0,
      mealLimitMinutes: (json['mealLimitMinutes'] as num?)?.toInt(),
      mealExceeded: json['mealExceeded'] == true,
      mealExcessMinutes: (json['mealExcessMinutes'] as num?)?.toInt() ?? 0,
      schedule: schedJson is Map<String, dynamic>
          ? EmployeeSchedule.fromJson(schedJson)
          : (schedJson is Map
                ? EmployeeSchedule.fromJson(Map<String, dynamic>.from(schedJson))
                : null),
    );
  }

  /// Fecha en formato "29 AGO 2026" para el historial.
  String get workDateLabel {
    final d = workDate;
    if (d == null) return '';
    const meses = [
      'ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN',
      'JUL', 'AGO', 'SEP', 'OCT', 'NOV', 'DIC',
    ];
    return '${d.day.toString().padLeft(2, '0')} ${meses[d.month - 1]} ${d.year}';
  }
}

/// Fila del panel administrativo: un empleado con su estado de hoy.
class AdminAttendanceRow {
  final String employeeId;
  final String name;
  final String email;
  final String? position;
  final bool hasSchedule;
  final AttendanceDay day;

  AdminAttendanceRow({
    required this.employeeId,
    required this.name,
    required this.email,
    required this.position,
    required this.hasSchedule,
    required this.day,
  });

  factory AdminAttendanceRow.fromJson(Map<String, dynamic> json) {
    return AdminAttendanceRow(
      employeeId: json['employeeId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      position: json['position']?.toString(),
      hasSchedule: json['hasSchedule'] == true,
      day: AttendanceDay.fromJson(json),
    );
  }
}

/// Fila del administrador de horarios: un empleado con su horario (o sin él).
class EmployeeScheduleRow {
  final String employeeId;
  final String name;
  final String email;
  final String? position;
  final EmployeeSchedule? schedule;

  EmployeeScheduleRow({
    required this.employeeId,
    required this.name,
    required this.email,
    required this.position,
    required this.schedule,
  });

  factory EmployeeScheduleRow.fromJson(Map<String, dynamic> json) {
    final schedJson = json['schedule'];
    return EmployeeScheduleRow(
      employeeId: json['employeeId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      position: json['position']?.toString(),
      schedule: schedJson is Map
          ? EmployeeSchedule.fromJson(Map<String, dynamic>.from(schedJson))
          : null,
    );
  }
}

/// Resumen de asistencia de un periodo (un mes). Devuelto por
/// GET /attendance/summary y por cada fila de GET /admin/attendance/summary.
class AttendancePeriodSummary {
  final int businessDays;
  final int workedDays;
  final int totalMinutes;
  final String totalLabel;
  final double totalHours;
  final int lateCount;
  final int lateMinutes;
  final int absentDays;
  final int vacationDays;
  final int incapacityDays;
  final int permissionDays;

  /// Porcentaje de días trabajados sin llegar tarde. `null` si no trabajó
  /// ningún día en el periodo.
  final int? onTimeRate;

  AttendancePeriodSummary({
    required this.businessDays,
    required this.workedDays,
    required this.totalMinutes,
    required this.totalLabel,
    required this.totalHours,
    required this.lateCount,
    required this.lateMinutes,
    required this.absentDays,
    required this.vacationDays,
    required this.incapacityDays,
    required this.permissionDays,
    required this.onTimeRate,
  });

  factory AttendancePeriodSummary.fromJson(Map<String, dynamic> json) {
    int n(String k) => (json[k] as num?)?.toInt() ?? 0;
    return AttendancePeriodSummary(
      businessDays: n('businessDays'),
      workedDays: n('workedDays'),
      totalMinutes: n('totalMinutes'),
      totalLabel: json['totalLabel']?.toString() ?? '0h',
      totalHours: (json['totalHours'] as num?)?.toDouble() ?? 0,
      lateCount: n('lateCount'),
      lateMinutes: n('lateMinutes'),
      absentDays: n('absentDays'),
      vacationDays: n('vacationDays'),
      incapacityDays: n('incapacityDays'),
      permissionDays: n('permissionDays'),
      onTimeRate: (json['onTimeRate'] as num?)?.toInt(),
    );
  }
}

/// Fila del resumen mensual por empleado (GET /admin/attendance/summary).
class AdminAttendanceSummaryRow {
  final String employeeId;
  final String name;
  final String? position;
  final String? departmentId;
  final AttendancePeriodSummary summary;

  AdminAttendanceSummaryRow({
    required this.employeeId,
    required this.name,
    required this.position,
    required this.departmentId,
    required this.summary,
  });

  factory AdminAttendanceSummaryRow.fromJson(Map<String, dynamic> json) =>
      AdminAttendanceSummaryRow(
        employeeId: json['employeeId']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        position: json['position']?.toString(),
        departmentId: json['departmentId']?.toString(),
        summary: AttendancePeriodSummary.fromJson(json),
      );
}

/// Tipo de fichaje que se pide corregir (mismos valores que
/// `attendance.type` en el backend).
enum CorrectionKind { entrada, inicioComida, finComida, salida }

CorrectionKind correctionKindFromString(String? v) => switch (v) {
      'inicio_comida' => CorrectionKind.inicioComida,
      'fin_comida' => CorrectionKind.finComida,
      'salida' => CorrectionKind.salida,
      _ => CorrectionKind.entrada,
    };

extension CorrectionKindInfo on CorrectionKind {
  String get apiValue => switch (this) {
        CorrectionKind.entrada => 'entrada',
        CorrectionKind.inicioComida => 'inicio_comida',
        CorrectionKind.finComida => 'fin_comida',
        CorrectionKind.salida => 'salida',
      };

  String get label => switch (this) {
        CorrectionKind.entrada => 'Entrada',
        CorrectionKind.inicioComida => 'Inicio de comida',
        CorrectionKind.finComida => 'Fin de comida',
        CorrectionKind.salida => 'Salida',
      };
}

enum CorrectionStatus { pendiente, aprobado, rechazado }

CorrectionStatus correctionStatusFromString(String? v) => switch (v) {
      'aprobado' => CorrectionStatus.aprobado,
      'rechazado' => CorrectionStatus.rechazado,
      _ => CorrectionStatus.pendiente,
    };

extension CorrectionStatusInfo on CorrectionStatus {
  String get apiValue => switch (this) {
        CorrectionStatus.pendiente => 'pendiente',
        CorrectionStatus.aprobado => 'aprobado',
        CorrectionStatus.rechazado => 'rechazado',
      };

  String get label => switch (this) {
        CorrectionStatus.pendiente => 'Pendiente',
        CorrectionStatus.aprobado => 'Aprobada',
        CorrectionStatus.rechazado => 'Rechazada',
      };
}

/// Solicitud de corrección de asistencia (tabla
/// `attendance_correction_requests`).
class AttendanceCorrection {
  final int id;
  final String employeeId;
  final String? employeeName;
  final DateTime? workDate;
  final CorrectionKind kind;
  final String kindLabel;

  /// Hora pedida, formato `HH:MM`.
  final String requestedTime;
  final String reason;
  final CorrectionStatus status;
  final String? reviewNote;
  final DateTime? createdAt;
  final DateTime? resolvedAt;

  AttendanceCorrection({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.workDate,
    required this.kind,
    required this.kindLabel,
    required this.requestedTime,
    required this.reason,
    required this.status,
    required this.reviewNote,
    required this.createdAt,
    required this.resolvedAt,
  });

  factory AttendanceCorrection.fromJson(Map<String, dynamic> json) {
    DateTime? d(String k) => DateTime.tryParse(json[k]?.toString() ?? '');
    return AttendanceCorrection(
      id: (json['id'] as num?)?.toInt() ?? 0,
      employeeId: json['employeeId']?.toString() ?? '',
      employeeName: json['employeeName']?.toString(),
      workDate: d('workDate'),
      kind: correctionKindFromString(json['kind']?.toString()),
      kindLabel: json['kindLabel']?.toString() ?? '',
      requestedTime: json['requestedTime']?.toString() ?? '',
      reason: json['reason']?.toString() ?? '',
      status: correctionStatusFromString(json['status']?.toString()),
      reviewNote: json['reviewNote']?.toString(),
      createdAt: d('createdAt'),
      resolvedAt: d('resolvedAt'),
    );
  }

  String get workDateLabel {
    final d = workDate;
    if (d == null) return '';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }
}
