import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:doliv_social/core/api_config.dart';
import 'package:doliv_social/core/session_keys.dart' show secureStorage, key;

/// Utilidades de chat usadas fuera de sus pantallas (p. ej. el contador de no
/// leídos del tablero).
class ChatService {
  static Future<String> _token() async =>
      (await secureStorage.readSecureData(key)) ?? '';

  /// Total de mensajes sin leer en todas las conversaciones. 0 ante error.
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
