// Modelos de permisos, vacaciones e incapacidades (/leave-requests/*). La
// evidencia solo llega como `hasEvidence`; se ve por endpoint autenticado.

import 'package:flutter/material.dart' show IconData, Icons;

enum LeaveType { vacaciones, incapacidad, permiso }

LeaveType leaveTypeFromString(String? v) {
  switch (v) {
    case 'incapacidad':
      return LeaveType.incapacidad;
    case 'permiso':
      return LeaveType.permiso;
    default:
      return LeaveType.vacaciones;
  }
}

extension LeaveTypeInfo on LeaveType {
  String get apiValue => switch (this) {
        LeaveType.vacaciones => 'vacaciones',
        LeaveType.incapacidad => 'incapacidad',
        LeaveType.permiso => 'permiso',
      };

  String get label => switch (this) {
        LeaveType.vacaciones => 'Vacaciones',
        LeaveType.incapacidad => 'Incapacidad',
        LeaveType.permiso => 'Permiso',
      };

  IconData get icon => switch (this) {
        LeaveType.vacaciones => Icons.beach_access_outlined,
        LeaveType.incapacidad => Icons.local_hospital_outlined,
        LeaveType.permiso => Icons.event_note_outlined,
      };

  /// La incapacidad exige evidencia antes de poder enviarse.
  bool get requiresEvidence => this == LeaveType.incapacidad;
}

enum LeaveStatus { pendiente, aprobado, rechazado, cancelado }

LeaveStatus leaveStatusFromString(String? v) {
  switch (v) {
    case 'aprobado':
      return LeaveStatus.aprobado;
    case 'rechazado':
      return LeaveStatus.rechazado;
    case 'cancelado':
      return LeaveStatus.cancelado;
    default:
      return LeaveStatus.pendiente;
  }
}

extension LeaveStatusInfo on LeaveStatus {
  String get label => switch (this) {
        LeaveStatus.pendiente => 'Pendiente',
        LeaveStatus.aprobado => 'Aprobado',
        LeaveStatus.rechazado => 'Rechazado',
        LeaveStatus.cancelado => 'Cancelado',
      };
}

/// Datos mínimos del empleado que envió la solicitud (solo panel del director).
class LeaveEmployee {
  final String id;
  final String name;
  final String email;
  final String? position;

  LeaveEmployee({
    required this.id,
    required this.name,
    required this.email,
    this.position,
  });

  factory LeaveEmployee.fromJson(Map<String, dynamic> json) => LeaveEmployee(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        email: json['email']?.toString() ?? '',
        position: json['position']?.toString(),
      );
}

class LeaveRequest {
  final String id;
  final LeaveType type;
  final LeaveStatus status;

  final DateTime? requestedStart;
  final DateTime? requestedEnd;
  final int requestedDays;

  final DateTime? approvedStart;
  final DateTime? approvedEnd;
  final int? approvedDays;

  final String? reason;
  final String? rejectionReason;
  final String? cancellationReason;

  final bool hasEvidence;

  final DateTime? createdAt;
  final DateTime? approvedAt;
  final DateTime? cancelledAt;

  final LeaveEmployee? employee; // solo en el panel del director

  /// Otras ausencias del departamento que se cruzan con estas fechas (solo lo
  /// llena `GET /admin/leave-requests/{id}`).
  final List<LeaveCalendarItem> deptOverlaps;

  LeaveRequest({
    required this.id,
    required this.type,
    required this.status,
    required this.requestedStart,
    required this.requestedEnd,
    required this.requestedDays,
    required this.approvedStart,
    required this.approvedEnd,
    required this.approvedDays,
    required this.reason,
    required this.rejectionReason,
    required this.cancellationReason,
    required this.hasEvidence,
    required this.createdAt,
    required this.approvedAt,
    required this.cancelledAt,
    required this.employee,
    this.deptOverlaps = const [],
  });

  factory LeaveRequest.fromJson(Map<String, dynamic> json) {
    DateTime? d(String key) => DateTime.tryParse(json[key]?.toString() ?? '');
    final empJson = json['employee'];
    return LeaveRequest(
      id: json['id']?.toString() ?? '',
      type: leaveTypeFromString(json['type']?.toString()),
      status: leaveStatusFromString(json['status']?.toString()),
      requestedStart: d('requestedStartDate'),
      requestedEnd: d('requestedEndDate'),
      requestedDays: (json['requestedDays'] as num?)?.toInt() ?? 0,
      approvedStart: d('approvedStartDate'),
      approvedEnd: d('approvedEndDate'),
      approvedDays: (json['approvedDays'] as num?)?.toInt(),
      reason: json['reason']?.toString(),
      rejectionReason: json['rejectionReason']?.toString(),
      cancellationReason: json['cancellationReason']?.toString(),
      hasEvidence: json['hasEvidence'] == true,
      createdAt: d('createdAt'),
      approvedAt: d('approvedAt'),
      cancelledAt: d('cancelledAt'),
      employee: empJson is Map
          ? LeaveEmployee.fromJson(Map<String, dynamic>.from(empJson))
          : null,
      deptOverlaps: ((json['deptOverlaps'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => LeaveCalendarItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  bool get isPending => status == LeaveStatus.pendiente;
  bool get isApproved => status == LeaveStatus.aprobado;

  static const _meses = [
    'ene', 'feb', 'mar', 'abr', 'may', 'jun',
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
  ];

  static String fmtDate(DateTime? d) {
    if (d == null) return '--';
    return '${d.day.toString().padLeft(2, '0')} ${_meses[d.month - 1]} ${d.year}';
  }

  static String fmtRange(DateTime? a, DateTime? b) {
    if (a == null || b == null) return '--';
    return '${fmtDate(a)} → ${fmtDate(b)}';
  }

  String get requestedRangeLabel => fmtRange(requestedStart, requestedEnd);
  String get approvedRangeLabel => fmtRange(approvedStart, approvedEnd);
}

/// Una ausencia en el calendario del equipo. El rango ya viene resuelto
/// (fechas aprobadas si lo está, si no las solicitadas).
class LeaveCalendarItem {
  final String id;
  final String employeeId;
  final String? employeeName;
  final String? departmentId;
  final String? departmentName;
  final LeaveType type;
  final String typeLabel;
  final LeaveStatus status;
  final String statusLabel;
  final DateTime? startDate;
  final DateTime? endDate;

  LeaveCalendarItem({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.departmentId,
    required this.departmentName,
    required this.type,
    required this.typeLabel,
    required this.status,
    required this.statusLabel,
    required this.startDate,
    required this.endDate,
  });

  factory LeaveCalendarItem.fromJson(Map<String, dynamic> json) {
    DateTime? d(String k) => DateTime.tryParse(json[k]?.toString() ?? '');
    return LeaveCalendarItem(
      id: json['id']?.toString() ?? '',
      employeeId: json['employeeId']?.toString() ?? '',
      employeeName: json['employeeName']?.toString(),
      departmentId: json['departmentId']?.toString(),
      departmentName: json['departmentName']?.toString(),
      type: leaveTypeFromString(json['type']?.toString()),
      typeLabel: json['typeLabel']?.toString() ?? '',
      status: leaveStatusFromString(json['status']?.toString()),
      statusLabel: json['statusLabel']?.toString() ?? '',
      startDate: d('startDate'),
      endDate: d('endDate'),
    );
  }

  /// `true` si el día [day] cae dentro del rango (inclusive).
  bool coversDay(DateTime day) {
    final s = startDate, e = endDate;
    if (s == null || e == null) return false;
    final d0 = DateTime(day.year, day.month, day.day);
    final s0 = DateTime(s.year, s.month, s.day);
    final e0 = DateTime(e.year, e.month, e.day);
    return !d0.isBefore(s0) && !d0.isAfter(e0);
  }

  String get rangeLabel =>
      LeaveRequest.fmtRange(startDate, endDate);
}
