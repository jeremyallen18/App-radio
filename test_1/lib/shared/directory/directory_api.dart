import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:doliv_social/models/models.dart';
import 'package:doliv_social/core/api_config.dart';
import 'package:doliv_social/core/session_keys.dart' show secureStorage, key;

/// Resultado de GET /user/directory: los compañeros que coinciden con la
/// búsqueda, más las áreas disponibles para filtrar y cuál es la del propio
/// usuario (para poder marcar "Mi área" sin una segunda llamada).
class DirectoryPage {
  final List<UserProfile> colleagues;
  final List<DepartmentInfo> departments;
  final String? myDepartmentId;

  DirectoryPage({
    required this.colleagues,
    required this.departments,
    this.myDepartmentId,
  });
}

/// Ámbito de búsqueda del directorio.
sealed class DirectoryScope {
  const DirectoryScope();

  /// Valor que espera el parámetro `scope` del backend.
  String get value;
}

/// El departamento del propio usuario. Si todavía no tiene uno asignado, el
/// backend responde con toda la empresa en vez de una lista vacía.
class MyAreaScope extends DirectoryScope {
  const MyAreaScope();

  @override
  String get value => 'department';
}

class CompanyScope extends DirectoryScope {
  const CompanyScope();

  @override
  String get value => 'company';
}

class DepartmentScope extends DirectoryScope {
  const DepartmentScope(this.departmentId);

  final String departmentId;

  @override
  String get value => departmentId;
}

/// Cliente del directorio interno (/user/directory y /user/profile/{id} en
/// hive-backend). Mismo patrón que `site_content_api.dart`: los errores de
/// red o de servidor salen como [DirectoryException] con un mensaje ya listo
/// para mostrar en español.
class DirectoryApi {
  static Future<String> _token() async {
    final token = await secureStorage.readSecureData(key);
    return token ?? '';
  }

  static Future<DirectoryPage> search({
    DirectoryScope scope = const MyAreaScope(),
    String query = '',
  }) async {
    final uri = Uri.parse('$kBaseUrl/user/directory').replace(
      queryParameters: <String, String>{
        'scope': scope.value,
        if (query.trim().isNotEmpty) 'q': query.trim(),
      },
    );

    final response = await _get(uri);
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;

    return DirectoryPage(
      colleagues: ((decoded['colleagues'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => UserProfile.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      departments: ((decoded['departments'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => DepartmentInfo.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      myDepartmentId: decoded['myDepartmentId'] as String?,
    );
  }

  static Future<ColleagueProfile> profile(String userId) async {
    final response = await _get(Uri.parse('$kBaseUrl/user/profile/$userId'));
    return ColleagueProfile.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  static Future<http.Response> _get(Uri uri) async {
    late final http.Response response;
    try {
      response = await http.get(uri, headers: {'Authorization': await _token()});
    } catch (_) {
      throw DirectoryException('No pudimos conectarnos con el servidor.');
    }
    if (response.statusCode != 200) {
      throw DirectoryException(_extractError(response.body));
    }
    return response;
  }

  static String _extractError(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['error'] != null) {
        return decoded['error'].toString();
      }
    } catch (_) {}
    return 'Ocurrió un error al comunicarse con el servidor.';
  }
}

class DirectoryException implements Exception {
  DirectoryException(this.message);
  final String message;

  @override
  String toString() => message;
}
