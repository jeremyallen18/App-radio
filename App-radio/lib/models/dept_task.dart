// Modelos del flujo jerárquico de tareas por departamento/equipo (Radio Doliv).
// Alimentados por /dept-tasks/* (hive-backend/dept_tasks.php).
//
//   Director  -> crea/edita/borra tareas de cualquier departamento.
//   Manager   -> tareas y subtareas de su departamento.
//   Empleado  -> solo cambia el estado (marcar completada).

enum DeptTaskStatus { pendiente, enProgreso, completada }

DeptTaskStatus deptTaskStatusFromString(String? v) {
  switch (v) {
    case 'en_progreso':
      return DeptTaskStatus.enProgreso;
    case 'completada':
      return DeptTaskStatus.completada;
    default:
      return DeptTaskStatus.pendiente;
  }
}

/// Estado de revisión del manager sobre una tarea que un empleado marcó como
/// completada (backend: `dept_tasks.review_status`).
enum DeptTaskReviewStatus { sinRevision, pendienteRevision, aprobada, rechazada }

DeptTaskReviewStatus deptTaskReviewStatusFromString(String? v) {
  switch (v) {
    case 'pendiente_revision':
      return DeptTaskReviewStatus.pendienteRevision;
    case 'aprobada':
      return DeptTaskReviewStatus.aprobada;
    case 'rechazada':
      return DeptTaskReviewStatus.rechazada;
    default:
      return DeptTaskReviewStatus.sinRevision;
  }
}

/// Recurrencia de una tarea (backend: `dept_tasks.recurrence`).
enum TaskRecurrence { none, daily, weekdays, weekly, monthly }

TaskRecurrence taskRecurrenceFromString(String? v) => switch (v) {
      'daily' => TaskRecurrence.daily,
      'weekdays' => TaskRecurrence.weekdays,
      'weekly' => TaskRecurrence.weekly,
      'monthly' => TaskRecurrence.monthly,
      _ => TaskRecurrence.none,
    };

extension TaskRecurrenceInfo on TaskRecurrence {
  String get apiValue => name;

  String get label => switch (this) {
        TaskRecurrence.none => 'No se repite',
        TaskRecurrence.daily => 'Cada día',
        TaskRecurrence.weekdays => 'Lunes a viernes',
        TaskRecurrence.weekly => 'Cada semana',
        TaskRecurrence.monthly => 'Cada mes',
      };
}

extension DeptTaskStatusInfo on DeptTaskStatus {
  String get apiValue => switch (this) {
        DeptTaskStatus.pendiente => 'pendiente',
        DeptTaskStatus.enProgreso => 'en_progreso',
        DeptTaskStatus.completada => 'completada',
      };

  String get label => switch (this) {
        DeptTaskStatus.pendiente => 'Pendiente',
        DeptTaskStatus.enProgreso => 'En progreso',
        DeptTaskStatus.completada => 'Completada',
      };
}

/// Referencia mínima a un usuario (asignado / creador / quien completó).
class TaskUserRef {
  final String id;
  final String name;
  final String email;
  final String? role;

  TaskUserRef({required this.id, required this.name, required this.email, this.role});

  factory TaskUserRef.fromJson(Map<String, dynamic> json) => TaskUserRef(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        email: json['email']?.toString() ?? '',
        role: json['role']?.toString(),
      );

  static TaskUserRef? maybe(dynamic json) => json is Map
      ? TaskUserRef.fromJson(Map<String, dynamic>.from(json))
      : null;
}

class DeptTask {
  final String id;
  final String? parentId;
  final String departmentId;
  final String title;
  final String? description;
  final DeptTaskStatus status;
  final String statusLabel;
  final TaskUserRef? assignedTo;
  final TaskUserRef? createdBy;
  final String? createdByRole;
  final DateTime? dueDate;
  final TaskUserRef? completedBy;
  final DateTime? completedAt;
  final DateTime? createdAt;
  final int subtaskCount;
  final int subtaskDoneCount;

  /// Si al marcarla como completada hay que adjuntar evidencia (010).
  final bool requiresEvidence;

  /// Si ya tiene un archivo de evidencia adjunto (se ve con
  /// `DeptTaskApi.evidenceUrl`).
  final bool hasEvidence;

  /// Revisión del manager (011).
  final DeptTaskReviewStatus reviewStatus;
  final String reviewStatusLabel;
  final String? reviewNote;
  final TaskUserRef? reviewedBy;
  final DateTime? reviewedAt;

  /// Recurrencia (012).
  final TaskRecurrence recurrence;
  final DateTime? recurrenceUntil;

  DeptTask({
    required this.id,
    required this.parentId,
    required this.departmentId,
    required this.title,
    required this.description,
    required this.status,
    required this.statusLabel,
    required this.assignedTo,
    required this.createdBy,
    required this.createdByRole,
    required this.dueDate,
    required this.completedBy,
    required this.completedAt,
    required this.createdAt,
    required this.subtaskCount,
    required this.subtaskDoneCount,
    required this.requiresEvidence,
    required this.hasEvidence,
    required this.reviewStatus,
    required this.reviewStatusLabel,
    required this.reviewNote,
    required this.reviewedBy,
    required this.reviewedAt,
    required this.recurrence,
    required this.recurrenceUntil,
  });

  factory DeptTask.fromJson(Map<String, dynamic> json) {
    DateTime? d(String k) => DateTime.tryParse(json[k]?.toString() ?? '');
    return DeptTask(
      id: json['id']?.toString() ?? '',
      parentId: json['parentId']?.toString(),
      departmentId: json['departmentId']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      status: deptTaskStatusFromString(json['status']?.toString()),
      statusLabel: json['statusLabel']?.toString() ?? 'Pendiente',
      assignedTo: TaskUserRef.maybe(json['assignedTo']),
      createdBy: TaskUserRef.maybe(json['createdBy']),
      createdByRole: json['createdByRole']?.toString(),
      dueDate: d('dueDate'),
      completedBy: TaskUserRef.maybe(json['completedBy']),
      completedAt: d('completedAt'),
      createdAt: d('createdAt'),
      subtaskCount: (json['subtaskCount'] as num?)?.toInt() ?? 0,
      subtaskDoneCount: (json['subtaskDoneCount'] as num?)?.toInt() ?? 0,
      requiresEvidence: json['requiresEvidence'] == true,
      hasEvidence: json['hasEvidence'] == true,
      reviewStatus: deptTaskReviewStatusFromString(json['reviewStatus']?.toString()),
      reviewStatusLabel: json['reviewStatusLabel']?.toString() ?? 'Sin revisión',
      reviewNote: json['reviewNote']?.toString(),
      reviewedBy: TaskUserRef.maybe(json['reviewedBy']),
      reviewedAt: d('reviewedAt'),
      recurrence: taskRecurrenceFromString(json['recurrence']?.toString()),
      recurrenceUntil: d('recurrenceUntil'),
    );
  }

  bool get isSubtask => parentId != null;
  bool get isDone => status == DeptTaskStatus.completada;

  /// Completada por un empleado y a la espera de que el manager la revise.
  bool get awaitingReview =>
      reviewStatus == DeptTaskReviewStatus.pendienteRevision;

  /// El manager la devolvió con una nota (visible para el empleado).
  bool get wasRejected => reviewStatus == DeptTaskReviewStatus.rechazada;

  bool get isRecurring => recurrence != TaskRecurrence.none;

  String? get dueLabel {
    final d = dueDate;
    if (d == null) return null;
    const m = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
    return '${d.day.toString().padLeft(2, '0')} ${m[d.month - 1]}';
  }
}

/// Un comentario del hilo de una tarea (backend: `dept_task_comments`,
/// GET/POST /dept-tasks/{id}/comments).
class TaskComment {
  final String id;
  final String body;
  final TaskUserRef? author;
  final DateTime? createdAt;

  TaskComment({
    required this.id,
    required this.body,
    required this.author,
    required this.createdAt,
  });

  factory TaskComment.fromJson(Map<String, dynamic> json) => TaskComment(
        id: json['id']?.toString() ?? '',
        body: json['body']?.toString() ?? '',
        author: TaskUserRef.maybe(json['author']),
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      );
}
