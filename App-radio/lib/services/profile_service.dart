import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:doliv_social/core/api_config.dart';
import 'package:doliv_social/core/session.dart';
import 'package:doliv_social/core/session_keys.dart' show secureStorage, key;
import 'package:doliv_social/models/models.dart';
import 'package:doliv_social/services/team_service.dart';

/// Error de la pantalla de perfil, con mensaje en español listo para mostrar.
class ProfileException implements Exception {
  ProfileException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Datos que alimentan "Mi perfil": el perfil del usuario, los contadores de
/// tareas y la lista de equipos. Los contadores/equipos son `null`/vacío si su
/// endpoint falla, igual que antes (la pantalla los muestra como "—").
class ProfileOverview {
  const ProfileOverview({
    required this.profile,
    required this.pendingCount,
    required this.completedCount,
    required this.teams,
  });

  final UserProfile? profile;
  final int? pendingCount;
  final int? completedCount;
  final List<dynamic> teams;
}

/// Contadores de toda la organización que ve un director en su perfil
/// ("Vista general"). Cada campo es `null` si su endpoint falla, y la
/// pantalla lo pinta como "—".
class DirectorOrgStats {
  const DirectorOrgStats({
    this.areasCount,
    this.collaboratorsCount,
    this.pendingCount,
    this.completedCount,
  });

  final int? areasCount;
  final int? collaboratorsCount;
  final int? pendingCount;
  final int? completedCount;
}

/// Cliente de los endpoints que usa la pantalla de perfil (hive-backend).
class ProfileApi {
  static Future<String> _token() async {
    final token = await secureStorage.readSecureData(key);
    return (token as String?) ?? '';
  }

  /// Carga en paralelo el perfil, los contadores de tareas y los equipos.
  static Future<ProfileOverview> fetchOverview() async {
    final token = await _token();

    Future<int?> count(String path, String field) async {
      try {
        final response = await http.get(
          Uri.parse('$kBaseUrl/$path'),
          headers: <String, String>{'Authorization': token},
        );
        if (response.statusCode != 200) return null;
        final List<dynamic> list = jsonDecode(response.body)[field] ?? [];
        return list.length;
      } catch (_) {
        return null;
      }
    }

    Future<List<dynamic>> teams() async {
      try {
        final response = await http.get(
          Uri.parse('$kBaseUrl/team/showTeams'),
          headers: <String, String>{'Authorization': token},
        );
        if (response.statusCode != 200) return [];
        return jsonDecode(response.body)['teams'] ?? [];
      } catch (_) {
        return [];
      }
    }

    final results = await Future.wait([
      Session.fetchCurrentUser(token),
      count('team/incompleteTasks', 'incompleteTasks'),
      count('team/completedTasks', 'completedTasks'),
      teams(),
    ]);

    return ProfileOverview(
      profile: results[0] as UserProfile?,
      pendingCount: results[1] as int?,
      completedCount: results[2] as int?,
      teams: results[3] as List<dynamic>,
    );
  }

  /// Resumen de organización para el perfil del director: nº de áreas y de
  /// colaboradores (del listado de departamentos) más los totales de tareas
  /// de toda la empresa (`dept-tasks/summary/by-department`). Cada mitad
  /// falla por separado sin tumbar a la otra.
  static Future<DirectorOrgStats> fetchDirectorOrg() async {
    Future<DeptTasksByDepartment?> summary() async {
      try {
        return await DeptTaskApi.summaryByDepartment();
      } catch (_) {
        return null;
      }
    }

    Future<List<DepartmentInfo>?> departments() async {
      try {
        return await TeamApi.listDepartments();
      } catch (_) {
        return null;
      }
    }

    final results = await Future.wait([summary(), departments()]);
    final s = results[0] as DeptTasksByDepartment?;
    final depts = results[1] as List<DepartmentInfo>?;

    return DirectorOrgStats(
      areasCount: depts?.length,
      collaboratorsCount:
          depts?.fold<int>(0, (n, d) => n + d.employeeCount),
      pendingCount: s?.totalPending,
      completedCount: s?.totalDone,
    );
  }

  /// Sube la foto de perfil y devuelve el perfil actualizado. Lanza
  /// [ProfileException] con el mensaje del backend (o uno genérico) si falla.
  static Future<UserProfile> uploadPhoto(String filePath) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$kBaseUrl/user/photo'),
      );
      request.headers['Authorization'] = await _token();
      request.files.add(await http.MultipartFile.fromPath('photo', filePath));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return UserProfile.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        );
      }
      String message = 'No se pudo actualizar la foto';
      try {
        message = (jsonDecode(response.body)['error'] as String?) ?? message;
      } catch (_) {}
      throw ProfileException(message);
    } on ProfileException {
      rethrow;
    } catch (_) {
      throw ProfileException('Ocurrió un error al subir la foto');
    }
  }

  /// Corrige el número de control de una persona (solo director). [number] es
  /// el entero de la secuencia; el backend lo formatea a `SPPRD-0000000`.
  /// Lanza [ProfileException] con el mensaje del backend (formato inválido,
  /// número ya en uso, etc.).
  static Future<UserProfile> updateControlNumber(
      String userId, int number) async {
    try {
      final response = await http.post(
        Uri.parse('$kBaseUrl/user/$userId/control-number'),
        headers: {'Authorization': await _token()},
        body: {'number': number.toString()},
      );
      if (response.statusCode == 200) {
        return UserProfile.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        );
      }
      String message = 'No se pudo actualizar el número de control';
      try {
        message = (jsonDecode(response.body)['error'] as String?) ?? message;
      } catch (_) {}
      throw ProfileException(message);
    } on ProfileException {
      rethrow;
    } catch (_) {
      throw ProfileException(
          'Ocurrió un error al actualizar el número de control');
    }
  }
}
