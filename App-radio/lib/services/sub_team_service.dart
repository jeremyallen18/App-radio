import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:doliv_social/core/api_config.dart';
import 'package:doliv_social/core/session_keys.dart' show secureStorage, key;
import 'package:doliv_social/models/sub_team.dart';
import 'package:doliv_social/services/team_service.dart' show TeamException;

/// Sub-equipos de un departamento (migración 030).
///
/// - Director / manager del área: `create`, `update`, `delete`, `setLead`.
/// - Sub-líder: `addMember` / `removeMember` de SU sub-equipo.
///
/// Reutiliza [TeamException] para que las pantallas de gestión de equipos
/// manejen un solo tipo de error.
class SubTeamApi {
  static Future<String> _token() async {
    final t = await secureStorage.readSecureData(key);
    return (t as String?) ?? '';
  }

  static Future<http.Response> _get(Uri uri) => _send(() async =>
      http.get(uri, headers: {'Authorization': await _token()}));

  static Future<http.Response> _post(Uri uri, Map<String, String> body) =>
      _send(() async =>
          http.post(uri, headers: {'Authorization': await _token()}, body: body));

  static Future<http.Response> _send(Future<http.Response> Function() run) async {
    late final http.Response res;
    try {
      res = await run();
    } catch (_) {
      throw TeamException(
          'No se pudo completar la operación debido a un error de conexión.');
    }
    if (res.statusCode != 200) {
      String msg = 'No se pudo completar la operación. Inténtalo nuevamente.';
      try {
        final d = jsonDecode(res.body);
        if (d is Map && (d['message'] ?? d['error']) != null) {
          msg = (d['message'] ?? d['error']).toString();
        }
      } catch (_) {}
      throw TeamException(msg);
    }
    return res;
  }

  static Map<String, dynamic> _body(http.Response res) =>
      jsonDecode(res.body) as Map<String, dynamic>;

  static SubTeam _one(http.Response res) =>
      SubTeam.fromJson(_body(res)['subTeam'] as Map<String, dynamic>);

  static Future<List<SubTeam>> list(String departmentId) async {
    final uri = Uri.parse('$kBaseUrl/subteam/list')
        .replace(queryParameters: {'departmentId': departmentId});
    final res = await _get(uri);
    return ((_body(res)['subTeams'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => SubTeam.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<SubTeam> create({
    required String departmentId,
    required String name,
    String? description,
  }) async {
    final res = await _post(Uri.parse('$kBaseUrl/subteam/create'), {
      'departmentId': departmentId,
      'name': name.trim(),
      if (description != null && description.trim().isNotEmpty)
        'description': description.trim(),
    });
    return _one(res);
  }

  static Future<SubTeam> update(
    String id, {
    String? name,
    String? description,
  }) async {
    final res = await _post(Uri.parse('$kBaseUrl/subteam/$id'), {
      if (name != null) 'name': name.trim(),
      if (description != null) 'description': description.trim(),
    });
    return _one(res);
  }

  static Future<void> delete(String id) async {
    await _post(Uri.parse('$kBaseUrl/subteam/$id/delete'), {});
  }

  /// `userId` vacío = quitar al líder.
  static Future<SubTeam> setLead(String id, String userId) async {
    final res = await _post(
      Uri.parse('$kBaseUrl/subteam/$id/setLead'),
      {'userId': userId},
    );
    return _one(res);
  }

  static Future<SubTeam> addMember(String id, String userId) async {
    final res = await _post(
      Uri.parse('$kBaseUrl/subteam/$id/addMember'),
      {'userId': userId},
    );
    return _one(res);
  }

  static Future<SubTeam> removeMember(String id, String userId) async {
    final res = await _post(
      Uri.parse('$kBaseUrl/subteam/$id/removeMember'),
      {'userId': userId},
    );
    return _one(res);
  }
}
