// Modelos de la estructura organizacional: rol y departamento de una persona.
// Alimentados por GET /user/me, /user/directory y /user/profile/{id}.

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

extension AppRoleLabel on AppRole {
  /// Nombre del rol para la UI.
  String get label {
    switch (this) {
      case AppRole.director:
        return 'Director General';
      case AppRole.manager:
        return 'Manager de Departamento';
      case AppRole.employee:
        return 'Empleado';
    }
  }

  /// Forma corta (una palabra) para espacios estrechos.
  String get shortLabel {
    switch (this) {
      case AppRole.director:
        return 'Director';
      case AppRole.manager:
        return 'Manager';
      case AppRole.employee:
        return 'Empleado';
    }
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

  /// Número de control único (`SPPRD-0000000`); lo autoasigna el alta y solo el
  /// director lo corrige. `null` si falta.
  final String? controlNumber;
  final String? photoUrl;
  final DepartmentInfo? department;

  /// Si el correo está verificado. Si el campo falta, se asume `true`.
  final bool emailVerified;

  /// Sub-equipos que esta persona lidera (solo en `GET /user/me`).
  final List<({String id, String name, String departmentId})> ledSubTeams;

  /// Correo nuevo a la espera de confirmarse (solo en `GET /user/me`).
  final String? pendingEmail;

  UserProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.position,
    this.controlNumber,
    this.photoUrl,
    this.department,
    this.emailVerified = true,
    this.ledSubTeams = const [],
    this.pendingEmail,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final deptJson = json['department'];
    return UserProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      role: appRoleFromString(json['role'] as String?),
      position: json['position'] as String?,
      controlNumber: json['controlNumber'] as String?,
      photoUrl: json['photoUrl'] as String?,
      department: deptJson is Map<String, dynamic>
          ? DepartmentInfo.fromJson(deptJson)
          : null,
      emailVerified:
          json.containsKey('emailVerified') ? json['emailVerified'] == true : true,
      pendingEmail: (json['pendingEmail']?.toString().isNotEmpty ?? false)
          ? json['pendingEmail'].toString()
          : null,
      ledSubTeams: ((json['ledSubTeams'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => (
                id: e['id']?.toString() ?? '',
                name: e['name']?.toString() ?? '',
                departmentId: e['departmentId']?.toString() ?? '',
              ))
          .toList(),
    );
  }

  /// Línea bajo el nombre: el puesto si lo tiene, si no el rol.
  String get headline =>
      (position ?? '').isNotEmpty ? position! : role.label;

  /// Número de control para mostrar; "Sin asignar" si todavía no tiene.
  String get controlNumberLabel =>
      (controlNumber ?? '').isNotEmpty ? controlNumber! : 'Sin asignar';

  /// Si esta persona dirige su propio departamento (compara `manager_email`).
  bool get leadsOwnDepartment =>
      department != null &&
      (department!.managerEmail ?? '').toLowerCase() == email.toLowerCase();
}

/// Equipo de un compañero (GET /user/profile/{id}); sin `teamCode`.
class ColleagueTeam {
  final String id;
  final String name;
  final bool isLeader;

  ColleagueTeam({required this.id, required this.name, required this.isLeader});

  factory ColleagueTeam.fromJson(Map<String, dynamic> json) {
    return ColleagueTeam(
      id: json['id']?.toString() ?? '',
      name: json['teamName']?.toString() ?? 'Equipo',
      isLeader: json['isLeader'] == true,
    );
  }
}

/// Ficha completa de un compañero: perfil público + equipos y antigüedad.
class ColleagueProfile {
  final UserProfile user;
  final List<ColleagueTeam> teams;
  final DateTime? joinedAt;

  ColleagueProfile({required this.user, required this.teams, this.joinedAt});

  factory ColleagueProfile.fromJson(Map<String, dynamic> json) {
    final teamsJson = (json['teams'] as List?) ?? const [];
    return ColleagueProfile(
      user: UserProfile.fromJson(json),
      teams: teamsJson
          .whereType<Map>()
          .map((t) => ColleagueTeam.fromJson(Map<String, dynamic>.from(t)))
          .toList(),
      joinedAt: DateTime.tryParse(json['joinedAt']?.toString() ?? ''),
    );
  }
}
