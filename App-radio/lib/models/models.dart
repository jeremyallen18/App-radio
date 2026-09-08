// Modelos de la estructura organizacional (Radio Doliv): rol de una persona
// y el departamento al que pertenece. Alimentados por GET /user/me (perfil
// propio, ver lib/utils/session.dart) y por GET /user/directory y
// GET /user/profile/{id} (directorio de compañeros, ver
// lib/screens/directory/directory_api.dart), que devuelven la misma forma.

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
  /// Nombre del rol para mostrar en la UI (requisito: 100% en español).
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

  /// Forma corta (una palabra) para espacios estrechos como el chip del header.
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

  /// Número de control único e intransferible (`SPPRD-0000000`). El alta lo
  /// autoasigna; solo el director lo corrige. `null` si el backend es anterior
  /// a la migración 028 o si el autoasignado falló en el alta.
  final String? controlNumber;
  final String? photoUrl;
  final DepartmentInfo? department;

  /// Si el correo de esta cuenta está verificado (backend `emailVerified`,
  /// migración 023). Un backend anterior no manda el campo: en ese caso se
  /// asume `true` para no mostrar un aviso incorrecto.
  final bool emailVerified;

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
    );
  }

  /// Línea que va debajo del nombre en el perfil y en el directorio: el
  /// puesto concreto si lo tiene y, si no, el rol — nunca vacío.
  String get headline =>
      (position ?? '').isNotEmpty ? position! : role.label;

  /// Número de control para mostrar; "Sin asignar" si todavía no tiene.
  String get controlNumberLabel =>
      (controlNumber ?? '').isNotEmpty ? controlNumber! : 'Sin asignar';

  /// Si esta persona es quien dirige su propio departamento. El backend
  /// referencia al manager por correo (`departments.manager_email`), así que
  /// se compara sin distinguir mayúsculas.
  bool get leadsOwnDepartment =>
      department != null &&
      (department!.managerEmail ?? '').toLowerCase() == email.toLowerCase();
}

/// Equipo al que pertenece un compañero, tal como lo devuelve
/// GET /user/profile/{id}. No incluye `teamCode`: el código sirve para
/// unirse al equipo, así que no se expone en la ficha de otra persona.
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

/// Ficha completa de un compañero: su perfil público más lo que solo trae el
/// detalle (equipos y antigüedad).
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
