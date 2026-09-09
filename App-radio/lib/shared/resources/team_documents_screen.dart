import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/models/team_document.dart';
import 'package:doliv_social/services/document_service.dart';

/// Apartado "Documentos" de Recursos del equipo: cualquier miembro sube y
/// descarga archivos de oficina (PDF, Word, Excel, PowerPoint, txt, csv,
/// zip). A diferencia de "Publicar recursos" (solo texto o una imagen
/// suelta), aquí se conserva el nombre y el formato original. Borra quien lo
/// subió o el líder del equipo (el backend lo valida).
class TeamDocumentsScreen extends StatefulWidget {
  const TeamDocumentsScreen(this.teamId, {super.key});

  final String teamId;

  @override
  State<TeamDocumentsScreen> createState() => _TeamDocumentsScreenState();
}

const List<String> _kAllowedExtensions = [
  'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx',
  'txt', 'csv', 'zip', 'rar', '7z',
];

class _TeamDocumentsScreenState extends State<TeamDocumentsScreen> {
  List<TeamDocument> _documents = const [];
  bool _loading = true;
  String? _error;
  bool _uploading = false;
  String? _busyId; // id del documento que se está descargando/eliminando
  String? _openingId; // id del documento que se está abriendo en el visor

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final docs = await DocumentService.list(widget.teamId);
      if (!mounted) return;
      setState(() {
        _documents = docs;
        _loading = false;
      });
    } on DocumentException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickAndUpload() async {
    final PlatformFile? file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: _kAllowedExtensions,
    );
    if (file == null) return;

    setState(() => _uploading = true);
    try {
      final bytes = await file.readAsBytes();
      await DocumentService.upload(
        teamId: widget.teamId,
        docName: file.name,
        filename: file.name,
        bytes: bytes,
      );
      _snack('Documento subido.');
      await _load();
    } on DocumentException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('No se pudo leer el archivo elegido.');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _open(TeamDocument doc) async {
    setState(() => _openingId = doc.id);
    try {
      final opened = await DocumentService.fetchToTemp(doc);
      final result = await OpenFilex.open(opened.path);
      if (result.type != ResultType.done && mounted) {
        _snack('No se pudo abrir el documento. Instala una app compatible '
            'con .${doc.extension} o descárgalo.');
      }
    } on DocumentException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('Ocurrió un error al abrir el documento.');
    } finally {
      if (mounted) setState(() => _openingId = null);
    }
  }

  Future<void> _download(TeamDocument doc) async {
    setState(() => _busyId = doc.id);
    try {
      final dl = await DocumentService.download(doc);
      final Uri? saved = await FilePicker.saveFile(
        fileName: dl.filename,
        bytes: dl.bytes,
        mimeType: dl.mime ?? 'application/octet-stream',
        dialogTitle: 'Guardar documento',
      );
      if (saved != null) _snack('Documento guardado.');
    } on DocumentException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('No se pudo guardar el documento.');
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _delete(TeamDocument doc) async {
    final ok = await showAppConfirmDialog(
      context,
      title: 'Eliminar documento',
      message:
          '¿Eliminar "${doc.docName}"? Esta acción no se puede deshacer.',
      confirmLabel: 'Eliminar',
      danger: true,
    );
    if (ok != true) return;

    setState(() => _busyId = doc.id);
    try {
      await DocumentService.delete(doc.id);
      if (!mounted) return;
      setState(() =>
          _documents = _documents.where((d) => d.id != doc.id).toList());
      _snack('Documento eliminado.');
    } on DocumentException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      padding: EdgeInsets.zero,
      appBar: AppBar(
        title: const Text('Documentos'),
        automaticallyImplyLeading: false,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _uploading ? null : _pickAndUpload,
        icon: _uploading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.upload_file_rounded),
        label: Text(_uploading ? 'Subiendo…' : 'Subir'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const LoadingState();
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);
    if (_documents.isEmpty) {
      return const EmptyState(
        icon: Icons.folder_open_outlined,
        title: 'Aún no hay documentos',
        message: 'Toca "Subir" para compartir un archivo con el equipo.',
      );
    }
    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
        itemCount: _documents.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) => _DocumentCard(
          doc: _documents[index],
          busy: _busyId == _documents[index].id,
          opening: _openingId == _documents[index].id,
          onOpen: () => _open(_documents[index]),
          onDownload: () => _download(_documents[index]),
          onDelete: () => _delete(_documents[index]),
        ),
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({
    required this.doc,
    required this.busy,
    required this.opening,
    required this.onOpen,
    required this.onDownload,
    required this.onDelete,
  });

  final TeamDocument doc;
  final bool busy;
  final bool opening;
  final VoidCallback onOpen;
  final VoidCallback onDownload;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final style = doc.typeStyle;
    final meta = [
      if (doc.formattedSize.isNotEmpty) doc.formattedSize,
      _shortEmail(doc.uploadedBy),
      _formatDate(doc.createdAt),
    ].join(' · ');

    return AppCard(
      // Tocar la tarjeta (fuera de los botones) abre el documento con el
      // visor nativo del sistema.
      onTap: (busy || opening) ? null : onOpen,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: style.color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Icon(style.icon, color: style.color, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doc.docName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  meta,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (busy)
            const Padding(
              padding: EdgeInsets.all(8),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else ...[
            opening
                ? const Padding(
                    padding: EdgeInsets.all(10),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    tooltip: 'Ver',
                    onPressed: onOpen,
                    icon: const Icon(Icons.visibility_rounded, size: 20),
                    color: AppColors.accent,
                    visualDensity: VisualDensity.compact,
                  ),
            IconButton(
              tooltip: 'Descargar',
              onPressed: onDownload,
              icon: const Icon(Icons.download_rounded, size: 20),
              color: AppColors.accentStrong,
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              tooltip: 'Eliminar',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
              color: AppColors.textMuted,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ],
      ),
    );
  }

  static String _shortEmail(String email) =>
      email.contains('@') ? email.substring(0, email.indexOf('@')) : email;

  static String _formatDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }
}
