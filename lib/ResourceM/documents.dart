import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../utils/api_config.dart';
import '../utils/session.dart';
import '../screens/login.dart';
import '../design/design.dart';
import 'resource_header.dart';

/// Pantalla "Documentos" de Resource Manager: a diferencia de "Publicar
/// recursos" (solo texto o una imagen suelta), aquí se sube cualquier
/// archivo de oficina (PDF, Word, Excel, PowerPoint, txt, csv, zip...) y se
/// puede descargar de vuelta al dispositivo con el nombre original.
class DocumentsScreen extends StatefulWidget {
  final String teamId;
  const DocumentsScreen(this.teamId, {super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class DocumentItem {
  final String id;
  final String docName;
  final String originalName;
  final int fileSize;
  final String uploadedBy;
  final DateTime createdAt;

  DocumentItem({
    required this.id,
    required this.docName,
    required this.originalName,
    required this.fileSize,
    required this.uploadedBy,
    required this.createdAt,
  });

  factory DocumentItem.fromJson(Map<String, dynamic> json) {
    return DocumentItem(
      id: json['id'].toString(),
      docName: json['docName'] ?? json['originalName'] ?? 'Documento',
      originalName: json['originalName'] ?? json['docName'] ?? 'documento',
      fileSize: (json['fileSize'] ?? 0) is int
          ? json['fileSize']
          : int.tryParse(json['fileSize'].toString()) ?? 0,
      uploadedBy: json['uploadedBy'] ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    );
  }

  String get extension {
    final parts = originalName.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : '';
  }

  String get formattedSize {
    if (fileSize <= 0) return '';
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get formattedDate => DateFormat('d MMM yyyy, HH:mm').format(createdAt);
}

/// Ícono + color según la extensión del archivo, para diferenciar de un
/// vistazo PDFs, hojas de cálculo, documentos de texto, etc.
class _DocTypeStyle {
  final IconData icon;
  final Color color;
  const _DocTypeStyle(this.icon, this.color);
}

_DocTypeStyle _styleFor(String extension) {
  switch (extension) {
    case 'pdf':
      return _DocTypeStyle(Icons.picture_as_pdf_rounded, AppColors.error);
    case 'doc':
    case 'docx':
      return _DocTypeStyle(Icons.description_rounded, AppColors.accent);
    case 'xls':
    case 'xlsx':
    case 'csv':
      return _DocTypeStyle(Icons.table_chart_rounded, AppColors.success);
    case 'ppt':
    case 'pptx':
      return _DocTypeStyle(Icons.slideshow_rounded, AppColors.warning);
    case 'zip':
    case 'rar':
    case '7z':
      return _DocTypeStyle(Icons.folder_zip_rounded, AppColors.accentStrong);
    case 'txt':
      return _DocTypeStyle(Icons.article_rounded, AppColors.textMuted);
    default:
      return _DocTypeStyle(Icons.insert_drive_file_rounded, AppColors.textMuted);
  }
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  List<DocumentItem> _documents = [];
  bool _isLoading = true;
  bool _hasError = false;
  bool _uploading = false;
  String? _downloadingId;
  String? _deletingId;
  String? _currentEmail;

  PlatformFile? _pickedFile;
  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCurrentEmail();
    _fetchDocuments();
  }

  Future<void> _loadCurrentEmail() async {
    final email = await Session.getCachedEmail();
    if (mounted) setState(() => _currentEmail = email);
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<String> _authHeader() async {
    final storedValue = await secureStorage.readSecureData(key);
    return storedValue ?? '';
  }

  Future<void> _fetchDocuments() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final token = await _authHeader();
      final response = await http.get(
        Uri.parse('$kBaseUrl/document/showDocuments/${widget.teamId}'),
        headers: {'Authorization': token},
      );
      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        final list = (body['data'] as List)
            .map((e) => DocumentItem.fromJson(e as Map<String, dynamic>))
            .toList();
        setState(() {
          _documents = list;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: const [
        'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx',
        'txt', 'csv', 'zip', 'rar', '7z',
      ],
    );
    if (result == null || result.files.isEmpty) return;
    setState(() {
      _pickedFile = result.files.single;
      _nameController.text = _pickedFile!.name;
    });
  }

  Future<void> _uploadDocument() async {
    final file = _pickedFile;
    if (file == null || file.bytes == null) {
      _showSnack('Elige un archivo primero.');
      return;
    }
    setState(() => _uploading = true);
    try {
      final token = await _authHeader();
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$kBaseUrl/document/addDocument'),
      );
      request.headers.addAll({'Authorization': token});
      request.fields.addAll({
        'teamId': widget.teamId,
        'docName': _nameController.text.trim(),
      });
      request.files.add(
        http.MultipartFile.fromBytes('document', file.bytes!, filename: file.name),
      );

      final response = await request.send();
      if (response.statusCode == 200) {
        _showSnack('Documento subido con éxito.');
        setState(() {
          _pickedFile = null;
          _nameController.clear();
        });
        _fetchDocuments();
      } else {
        final body = await response.stream.bytesToString();
        _showSnack(body.isNotEmpty ? body : 'No se pudo subir el documento.');
      }
    } catch (e) {
      _showSnack('Ocurrió un error al subir el documento.');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _downloadDocument(DocumentItem doc) async {
    setState(() => _downloadingId = doc.id);
    try {
      final token = await _authHeader();
      final response = await http.get(
        Uri.parse('$kBaseUrl/document/download/${doc.id}'),
        headers: {'Authorization': token},
      );
      if (response.statusCode == 200) {
        final Uint8List bytes = response.bodyBytes;
        final outputPath = await FilePicker.platform.saveFile(
          dialogTitle: 'Guardar documento',
          fileName: doc.originalName,
          bytes: bytes,
        );
        if (outputPath != null) {
          _showSnack('Documento descargado.');
        }
      } else {
        _showSnack('No se pudo descargar el documento.');
      }
    } catch (e) {
      _showSnack('Ocurrió un error al descargar el documento.');
    } finally {
      if (mounted) setState(() => _downloadingId = null);
    }
  }

  Future<void> _deleteDocument(DocumentItem doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Eliminar documento', style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          '¿Seguro que quieres eliminar "${doc.docName}"? Esta acción no se puede deshacer.',
          style: TextStyle(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Eliminar', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _deletingId = doc.id);
    try {
      final token = await _authHeader();
      final response = await http.delete(
        Uri.parse('$kBaseUrl/document/${doc.id}'),
        headers: {'Authorization': token},
      );
      if (response.statusCode == 200) {
        _showSnack('Documento eliminado.');
        setState(() => _documents.removeWhere((d) => d.id == doc.id));
      } else {
        _showSnack('No se pudo eliminar el documento.');
      }
    } catch (e) {
      _showSnack('Ocurrió un error al eliminar el documento.');
    } finally {
      if (mounted) setState(() => _deletingId = null);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ResourceHeader(
            title: 'Documentos',
            subtitle: 'Sube y descarga los documentos del equipo.',
          ),
          _UploadCard(
            pickedFile: _pickedFile,
            nameController: _nameController,
            uploading: _uploading,
            onPickFile: _pickFile,
            onClearFile: () => setState(() {
              _pickedFile = null;
              _nameController.clear();
            }),
            onUpload: _uploadDocument,
          ),
          const SizedBox(height: AppSpacing.lg),
          SectionHeader(title: 'Documentos del equipo (${_documents.length})'),
          Expanded(
            child: _isLoading
                ? const LoadingState(message: 'Cargando documentos...')
                : _hasError
                    ? ErrorState(onRetry: _fetchDocuments)
                    : _documents.isEmpty
                        ? const EmptyState(
                            icon: Icons.folder_open_rounded,
                            title: 'Todavía no hay documentos',
                            message: 'Sube el primero desde el botón de arriba.',
                          )
                        : RefreshIndicator(
                            onRefresh: _fetchDocuments,
                            child: ListView.separated(
                              padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: _documents.length,
                              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                              itemBuilder: (context, index) {
                                final doc = _documents[index];
                                return _DocumentTile(
                                  doc: doc,
                                  isDownloading: _downloadingId == doc.id,
                                  isDeleting: _deletingId == doc.id,
                                  canDelete: _currentEmail != null && _currentEmail == doc.uploadedBy,
                                  onDownload: () => _downloadDocument(doc),
                                  onDelete: () => _deleteDocument(doc),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class _UploadCard extends StatelessWidget {
  const _UploadCard({
    required this.pickedFile,
    required this.nameController,
    required this.uploading,
    required this.onPickFile,
    required this.onClearFile,
    required this.onUpload,
  });

  final PlatformFile? pickedFile;
  final TextEditingController nameController;
  final bool uploading;
  final VoidCallback onPickFile;
  final VoidCallback onClearFile;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Subir documento',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'PDF, Word, Excel, PowerPoint, txt, csv o comprimidos. Máx. 25 MB.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: AppSpacing.md),
          if (pickedFile == null)
            OutlinedButton.icon(
              onPressed: onPickFile,
              icon: const Icon(Icons.attach_file_rounded),
              label: const Text('Elegir archivo'),
            )
          else ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.bgBase,
                borderRadius: BorderRadius.circular(AppRadius.field),
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: Row(
                children: [
                  Icon(_styleFor(pickedFile!.extension ?? '').icon,
                      color: _styleFor(pickedFile!.extension ?? '').color, size: 22),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      pickedFile!.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
                    ),
                  ),
                  IconButton(
                    onPressed: onClearFile,
                    icon: Icon(Icons.close_rounded, color: AppColors.textMuted, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: nameController,
              hintText: 'Nombre del documento (opcional)',
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Subir documento',
              height: 44,
              loading: uploading,
              onPressed: uploading ? null : onUpload,
            ),
          ],
        ],
      ),
    );
  }
}

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({
    required this.doc,
    required this.isDownloading,
    required this.isDeleting,
    required this.canDelete,
    required this.onDownload,
    required this.onDelete,
  });

  final DocumentItem doc;
  final bool isDownloading;
  final bool isDeleting;
  final bool canDelete;
  final VoidCallback onDownload;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final style = _styleFor(doc.extension);
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: style.color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(AppRadius.chip),
              border: Border.all(color: style.color.withValues(alpha: 0.4)),
            ),
            child: Icon(style.icon, color: style.color, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doc.docName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (doc.uploadedBy.isNotEmpty) doc.uploadedBy,
                    if (doc.formattedSize.isNotEmpty) doc.formattedSize,
                    doc.formattedDate,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          if (canDelete)
            isDeleting
                ? const SizedBox(
                    width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : IconButton(
                    onPressed: onDelete,
                    icon: Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                    tooltip: 'Eliminar',
                  ),
          isDownloading
              ? const Padding(
                  padding: EdgeInsets.all(10),
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : IconButton(
                  onPressed: onDownload,
                  icon: Icon(Icons.download_rounded, color: AppColors.accent),
                  tooltip: 'Descargar',
                ),
        ],
      ),
    );
  }
}
