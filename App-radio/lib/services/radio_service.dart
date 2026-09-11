import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:doliv_social/core/api_config.dart';
import 'package:doliv_social/core/session_keys.dart' show secureStorage, key;
import 'package:doliv_social/models/radio_program.dart';

class RadioException implements Exception {
  RadioException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Cliente de solo lectura de la parrilla de Radio Doliv (`GET /radio/programs`).
class RadioProgramsApi {
  static Future<List<RadioProgram>> list() async {
    final token = (await secureStorage.readSecureData(key)) ?? '';
    late final http.Response res;
    try {
      res = await http.get(
        Uri.parse('$kBaseUrl/radio/programs'),
        headers: {'Authorization': token},
      );
    } catch (_) {
      throw RadioException('No se pudo cargar la programación. Revisa tu conexión.');
    }
    if (res.statusCode != 200) {
      throw RadioException('No se pudo cargar la programación.');
    }
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    return ((decoded['items'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => RadioProgram.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}
