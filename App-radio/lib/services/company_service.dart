import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:doliv_social/core/api_config.dart';
import 'package:doliv_social/core/session_keys.dart' show secureStorage, key;
import 'package:doliv_social/models/company.dart';

/// Error de gestión de la empresa, con mensaje en español listo para mostrar.
class CompanyException implements Exception {
  CompanyException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// La empresa única de Radio Doliv: consultarla y (solo director) crearla.
class CompanyApi {
  static Future<String> _token() async {
    final t = await secureStorage.readSecureData(key);
    return t ?? '';
  }

  /// `GET /company/info` → empresa, o `null` si aún no se creó (404). Lanza
  /// [CompanyException] ante un fallo real.
  static Future<Company?> fetch() async {
    late final http.Response res;
    try {
      res = await http.get(
        Uri.parse('$kBaseUrl/company/info'),
        headers: {'Authorization': await _token()},
      );
    } catch (_) {
      throw CompanyException(
          'No se pudo comprobar la empresa por un error de conexión.');
    }
    if (res.statusCode == 404) return null;
    if (res.statusCode != 200) throw CompanyException(_msg(res));
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final company = data['company'];
    if (company is! Map) return null;
    return Company.fromJson(Map<String, dynamic>.from(company));
  }

  /// `POST /company/create`. Solo si aún no existe (si no, 409).
  static Future<Company> create({
    required String name,
    String? description,
  }) async {
    late final http.Response res;
    try {
      res = await http.post(
        Uri.parse('$kBaseUrl/company/create'),
        headers: {'Authorization': await _token()},
        body: {
          'name': name.trim(),
          if (description != null && description.trim().isNotEmpty)
            'description': description.trim(),
        },
      );
    } catch (_) {
      throw CompanyException(
          'No se pudo crear la empresa por un error de conexión.');
    }
    if (res.statusCode != 200) throw CompanyException(_msg(res));
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return Company.fromJson(Map<String, dynamic>.from(data['company'] as Map));
  }

  static String _msg(http.Response res) {
    try {
      final d = jsonDecode(res.body);
      if (d is Map && (d['error'] ?? d['message']) != null) {
        return (d['error'] ?? d['message']).toString();
      }
    } catch (_) {}
    return 'No se pudo completar la operación. Inténtalo nuevamente.';
  }
}
