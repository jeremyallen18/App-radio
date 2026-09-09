import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'package:doliv_social/core/api_config.dart';
import 'package:doliv_social/core/session_keys.dart' show secureStorage, key;
import 'package:doliv_social/models/team_document.dart';
import 'package:doliv_social/services/document_service.dart'
    show DocumentException, DownloadedDocument, OpenedDocument;

/// Cliente de "Documentos por departamento" (endpoints `/department-documents/*`
/// en hive-backend). El RBAC lo aplica el backend:
///   - director: lista/sube/renombra/elimina en cualquier departamento;
///   - manager: lo mismo, solo en el suyo;
///   - resto: solo `list` + `download` de su departamento.
class DepartmentDocumentService {
  static Future<String> _token() async =>
      (await secureStorage.readSecureData(key)) ?? '';

  static Future<List<TeamDocument>> list(String departmentId) async {
    final uri = Uri.parse('$kBaseUrl/department-documents')
        .replace(queryParameters: {'departmentId': departmentId});
    late final http.Response res;
    try {
      res = await http.get(uri, headers: {'Authorization': await _token()});
    } catch (_) {
      throw DocumentException('No pudimos conectarnos con el servidor.');
    }
    if (res.statusCode != 200) {
      throw DocumentException(_extractError(res.body));
    }
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    return ((decoded['documents'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => TeamDocument.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<void> upload({
    required String departmentId,
    required String docName,
    required String filename,
    required List<int> bytes,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$kBaseUrl/department-documents'),
    )
      ..headers['Authorization'] = await _token()
      ..fields['departmentId'] = departmentId
      ..fields['docName'] = docName.trim()
      ..files.add(
          http.MultipartFile.fromBytes('document', bytes, filename: filename));

    late final http.StreamedResponse streamed;
    try {
      streamed = await request.send();
    } catch (_) {
      throw DocumentException('No pudimos conectarnos con el servidor.');
    }
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode != 200) {
      throw DocumentException(
          _extractError(body, fallback: 'No se pudo subir el documento.'));
    }
  }

  static Future<void> rename(String id, String docName) async {
    late final http.Response res;
    try {
      res = await http.post(
        Uri.parse('$kBaseUrl/department-documents/$id'),
        headers: {'Authorization': await _token()},
        body: {'docName': docName.trim()},
      );
    } catch (_) {
      throw DocumentException('No pudimos conectarnos con el servidor.');
    }
    if (res.statusCode != 200) {
      throw DocumentException(
          _extractError(res.body, fallback: 'No se pudo renombrar el documento.'));
    }
  }

  static Future<DownloadedDocument> download(TeamDocument doc) async {
    late final http.Response res;
    try {
      res = await http.get(
        Uri.parse('$kBaseUrl/department-documents/${doc.id}/download'),
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

  /// Descarga a la carpeta temporal y devuelve la ruta local, para abrir con
  /// `OpenFilex` (misma idea que `DocumentService.fetchToTemp`).
  static Future<OpenedDocument> fetchToTemp(TeamDocument doc) async {
    final dl = await download(doc);
    final dir = await getTemporaryDirectory();
    final safe = doc.originalName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final file = File('${dir.path}/${doc.id}_$safe');
    await file.writeAsBytes(dl.bytes, flush: true);
    return OpenedDocument(file.path);
  }

  static Future<void> delete(String id) async {
    late final http.Response res;
    try {
      res = await http.post(
        Uri.parse('$kBaseUrl/department-documents/$id/delete'),
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
