import 'package:doliv_social/models/dept_task.dart' show TaskUserRef;

/// Un sub-equipo dentro de un departamento (migración 030). Lo crea el manager
/// del área; un empleado del área puede estar en varios. `lead` es un
/// sub-líder opcional que administra los miembros y las tareas del sub-equipo.
/// Alimentado por `/subteam/*` (hive-backend/sub_teams.php).
class SubTeam {
  final String id;
  final String departmentId;
  final String name;
  final String? description;
  final TaskUserRef? lead;
  final int memberCount;
  final List<TaskUserRef> members;

  const SubTeam({
    required this.id,
    required this.departmentId,
    required this.name,
    required this.description,
    required this.lead,
    required this.memberCount,
    required this.members,
  });

  factory SubTeam.fromJson(Map<String, dynamic> json) {
    final members = ((json['members'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => TaskUserRef.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return SubTeam(
      id: json['id']?.toString() ?? '',
      departmentId: json['departmentId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      lead: TaskUserRef.maybe(json['lead']),
      memberCount: (json['memberCount'] as num?)?.toInt() ?? members.length,
      members: members,
    );
  }

  bool isLeadUser(String? userId) =>
      userId != null && lead != null && lead!.id == userId;
}
