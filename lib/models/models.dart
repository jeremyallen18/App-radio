// Modelos de la estructura organizacional (Radio Doliv): rol del usuario
// autenticado y el departamento al que pertenece. Alimentados por
// GET /user/me (ver lib/utils/session.dart).

enum AppRole { director, manager, employee }

AppRole appRoleFromString(String? value) {
  switch (value) {
    case 'director':
      return AppRole.director;
    case 'manager':
      return AppRole.manager;
    default:
      return AppRole.employee;
  }
}

class DepartmentInfo {
  final String id;
  final String companyId;
  final String name;
  final String? description;
  final String? managerEmail;
  final int employeeCount;

  DepartmentInfo({
    required this.id,
    required this.companyId,
    required this.name,
    this.description,
    this.managerEmail,
    required this.employeeCount,
  });

  factory DepartmentInfo.fromJson(Map<String, dynamic> json) {
    return DepartmentInfo(
      id: json['id'] as String,
      companyId: json['companyId'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      managerEmail: json['managerEmail'] as String?,
      employeeCount: (json['employeeCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class UserProfile {
  final String id;
  final String name;
  final String email;
  final AppRole role;
  final String? position;
  final DepartmentInfo? department;

  UserProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.position,
    this.department,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final deptJson = json['department'];
    return UserProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      role: appRoleFromString(json['role'] as String?),
      position: json['position'] as String?,
      department: deptJson is Map<String, dynamic>
          ? DepartmentInfo.fromJson(deptJson)
          : null,
    );
  }
}
