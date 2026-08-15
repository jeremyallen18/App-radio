import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../utils/api_config.dart';
import '../login.dart' show secureStorage, key;

/// Cliente HTTP para /site/* en hive-backend (gestión de contenido del
/// sitio público RADIODOLIV_PAGINA, exclusiva del director). Create/update
/// siempre van como multipart/form-data porque la imagen es opcional en
/// ambos casos — mismo patrón que la subida de foto de perfil en
/// `home_page/profile.dart`.
class SiteContentApi {
  SiteContentApi(this.resource);

  /// Segmento de URL del recurso: anuncios, eventos, patrocinadores,
  /// podcasts, servicios, equipo o programas.
  final String resource;

  Future<String> _token() async {
    final token = await secureStorage.readSecureData(key);
    return token ?? '';
  }

  Future<List<Map<String, dynamic>>> list() async {
    final response = await http.get(
      Uri.parse('$kBaseUrl/site/$resource'),
      headers: {'Authorization': await _token()},
    );
    if (response.statusCode != 200) {
      throw SiteContentException(_extractError(response.body));
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final List<dynamic> items = decoded['items'] ?? [];
    return items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> create(
    Map<String, String> fields, {
    File? imageFile,
    String imageField = 'image',
  }) {
    return _send(
      http.MultipartRequest('POST', Uri.parse('$kBaseUrl/site/$resource')),
      fields,
      imageFile: imageFile,
      imageField: imageField,
    );
  }

  Future<Map<String, dynamic>> update(
    String id,
    Map<String, String> fields, {
    File? imageFile,
    String imageField = 'image',
  }) {
    return _send(
      http.MultipartRequest('POST', Uri.parse('$kBaseUrl/site/$resource/$id')),
      fields,
      imageFile: imageFile,
      imageField: imageField,
    );
  }

  Future<void> delete(String id) async {
    final response = await http.post(
      Uri.parse('$kBaseUrl/site/$resource/$id/delete'),
      headers: {'Authorization': await _token()},
    );
    if (response.statusCode != 200) {
      throw SiteContentException(_extractError(response.body));
    }
  }

  Future<Map<String, dynamic>> _send(
    http.MultipartRequest request,
    Map<String, String> fields, {
    File? imageFile,
    required String imageField,
  }) async {
    request.headers['Authorization'] = await _token();
    request.fields.addAll(fields);
    if (imageFile != null) {
      request.files.add(await http.MultipartFile.fromPath(imageField, imageFile.path));
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw SiteContentException(_extractError(response.body));
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return Map<String, dynamic>.from(decoded['item'] as Map);
  }

  String _extractError(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['error'] != null) {
        return decoded['error'].toString();
      }
    } catch (_) {}
    return 'Ocurrió un error al comunicarse con el servidor.';
  }
}

class SiteContentException implements Exception {
  SiteContentException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Arma la URL completa de una imagen a partir de la ruta relativa que
/// guarda hive_db (p.ej. "assets/img/eventos/foo.jpg"), sirviéndola desde
/// RADIODOLIV_PAGINA. Devuelve null si no hay imagen todavía.
String? siteImageUrl(String? relativePath) {
  if (relativePath == null || relativePath.isEmpty) return null;
  return kSiteBaseUrl + relativePath;
}
