import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:doliv_social/core/api_config.dart';
import 'package:doliv_social/core/session_keys.dart' show secureStorage, key;

/// Utilidades de mensajería directa que se comparten fuera de las pantallas
/// de chat (p. ej. el contador de no leídos que se pinta sobre el botón
/// "Mensajes" del tablero). Las pantallas de chat siguen llamando a
/// `/chat/thread` y `/chat/conversations` directamente.
class ChatService {
  static Future<String> _token() async =>
      (await secureStorage.readSecureData(key)) ?? '';

  /// Suma de mensajes sin leer en todas las conversaciones del usuario.
  /// Devuelve 0 ante cualquier error (es un adorno, no debe romper la UI).
  static Future<int> unreadTotal() async {
    try {
      final res = await http.get(
        Uri.parse('$kBaseUrl/chat/conversations'),
        headers: {'Authorization': await _token()},
      );
      if (res.statusCode != 200) return 0;
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      final list = (decoded['conversations'] as List?) ?? const [];
      var total = 0;
      for (final c in list) {
        if (c is Map) total += (c['unread'] as num?)?.toInt() ?? 0;
      }
      return total;
    } catch (_) {
      return 0;
    }
  }
}
