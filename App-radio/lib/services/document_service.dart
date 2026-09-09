import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'package:doliv_social/core/api_config.dart';
import 'package:doliv_social/core/session_keys.dart' show secureStorage, key;
import 'package:doliv_social/models/team_document.dart';

/// Excepción con un mensaje ya listo para mostrar en español (mismo patrón
/// que `DirectoryApi` / `AttendanceApi`).
class DocumentException implements Exception {
  DocumentException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Archivo descargado: sus bytes y el nombre original con el que guardarlo.
class DownloadedDocument {
  DownloadedDocument({required this.bytes, required this.filename, this.mime});
  final Uint8List bytes;
  final String filename;
  final String? mime;
}

/// Documento escrito en un archivo local temporal, listo para abrirse con el
/// visor nativo del sistema (`OpenFilex`).
class OpenedDocument {
  OpenedDocument(this.path);
  final String path;
}

/// Cliente del apartado "Documentos" de un equipo (endpoints /document/* en
/// hive-backend). Cualquier miembro lista, sube y descarga; borra quien lo
/// subió o el líder.
class DocumentService {
  static Future<String> _token() async =>
      (await secureStorage.readSecureData(key)) ?? '';

  static Future<List<TeamDocument>> list(String teamId) async {
    final res = await _get(Uri.parse('$kBaseUrl/document/list/$teamId'));
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    return ((decoded['documents'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => TeamDocument.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<void> upload({
    required String teamId,
    required String docName,
    required String filename,
    required Uint8List bytes,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$kBaseUrl/document/upload'),
    )
      ..headers['Authorization'] = await _token()
      ..fields['teamId'] = teamId
      ..fields['docName'] = docName.trim()
      ..files.add(http.MultipartFile.fromBytes('document', bytes, filename: filename));

    late final http.StreamedResponse streamed;
    try {
      streamed = await request.send();
    } catch (_) {
      throw DocumentException('No pudimos conectarnos con el servidor.');
    }
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode != 200) {
      throw DocumentException(_extractError(body, fallback: 'No se pudo subir el documento.'));
    }
  }

  static Future<DownloadedDocument> download(TeamDocument doc) async {
    late final http.Response res;
    try {
      res = await http.get(
        Uri.parse('$kBaseUrl/document/download/${doc.id}'),
        headers: {'Authorization': await _token()},
      );
    } catch (_) {
      throw DocumentException('No pudimos conectarnos con el servidor.');
    }
    if (res.statusCode != 200) {
      throw DocumentException(
        _extractError(res.body, fallback: 'No se pudo descargar el documento.'),
      );
    }
    return DownloadedDocument(
      bytes: res.bodyBytes,
      filename: doc.originalName,
      mime: doc.mime,
    );
  }

  /// Limpia los caracteres que no son válidos como nombre de archivo en el
  /// sistema de archivos local (se usa para el archivo temporal antes de
  /// abrirlo con el visor nativo).
  static String sanitizeFileName(String name) =>
      name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

  /// Descarga el documento y lo escribe en la carpeta temporal del
  /// dispositivo; devuelve la ruta local para abrirlo con `OpenFilex`. Para
  /// "guardar como" (elegir carpeta) usa [download].
  ///
  /// Lanza [DocumentException] con un mensaje en español si el servidor no
  /// devuelve el archivo (404 → "El archivo ya no está disponible.").
  static Future<OpenedDocument> fetchToTemp(TeamDocument doc) async {
    final DownloadedDocument dl = await download(doc);
    final dir = await getTemporaryDirectory();
    final safe = sanitizeFileName(doc.originalName);
    final file = File('${dir.path}/${doc.id}_$safe');
    await file.writeAsBytes(dl.bytes, flush: true);
    return OpenedDocument(file.path);
  }

  static Future<void> delete(String documentId) async {
    late final http.Response res;
    try {
      res = await http.post(
        Uri.parse('$kBaseUrl/document/$documentId/delete'),
        headers: {'Authorization': await _token()},
      );
    } catch (_) {
      throw DocumentException('No pudimos conectarnos con el servidor.');
    }
    if (res.statusCode != 200) {
      throw DocumentException(
        _extractError(res.body, fallback: 'No se pudo eliminar el documento.'),
      );
    }
  }

  static Future<http.Response> _get(Uri uri) async {
    late final http.Response res;
    try {
      res = await http.get(uri, headers: {'Authorization': await _token()});
    } catch (_) {
      throw DocumentException('No pudimos conectarnos con el servidor.');
    }
    if (res.statusCode != 200) {
      throw DocumentException(_extractError(res.body));
    }
    return res;
  }

  static String _extractError(String body,
      {String fallback = 'Ocurrió un error al comunicarse con el servidor.'}) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['error'] != null) {
        return decoded['error'].toString();
      }
      if (decoded is Map && decoded['message'] != null) {
        return decoded['message'].toString();
      }
    } catch (_) {
      if (body.trim().isNotEmpty && body.length < 200) return body.trim();
    }
    return fallback;
  }
}
