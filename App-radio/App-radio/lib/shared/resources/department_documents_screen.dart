import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/models/team_document.dart';
import 'package:doliv_social/services/document_service.dart' show DocumentException;
import 'package:doliv_social/services/department_document_service.dart';

/// "Documentos del departamento": archivos de oficina compartidos dentro de
/// un departamento, con RBAC.
///
/// - [canManage] `true` (director / manager del departamento): puede subir,
///   renombrar y eliminar.
/// - [canManage] `false` (resto del departamento): solo ver, buscar y
///   descargar. El backend valida lo mismo por si acaso.
class DepartmentDocumentsScreen extends StatefulWidget {
  const DepartmentDocumentsScreen({
    super.key,
    required this.departmentId,
    required this.canManage,
    this.departmentName,
  });

  final String departmentId;
  final bool canManage;
  final String? departmentName;

  @override
  State<DepartmentDocumentsScreen> createState() =>
      _DepartmentDocumentsScreenState();
}

const List<String> _kAllowedExtensions = [
  'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx',
  'txt', 'csv', 'zip', 'rar', '7z',
];

class _DepartmentDocumentsScreenState
    extends State<DepartmentDocumentsScreen> {
  List<TeamDocument> _documents = const [];
  bool _loading = true;
  String? _error;
  bool _uploading = false;
  String? _busyId; // descargando / renombrando / eliminando
  String? _openingId; // abriendo en el visor
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<TeamDocument> get _filtered {
    if (_query.isEmpty) return _documents;
    return _documents
        .where((d) =>
            d.docName.toLowerCase().contains(_query) ||
            d.originalName.toLowerCase().contains(_query))
        .toList();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final docs = await DepartmentDocumentService.list(widget.departmentId);
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
      await DepartmentDocumentService.upload(
        departmentId: widget.departmentId,
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
      final opened = await DepartmentDocumentService.fetchToTemp(doc);
      final res = await OpenFilex.open(opened.path);
      if (res.type != ResultType.done && mounted) {
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
      final dl = await DepartmentDocumentService.download(doc);
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

  Future<void> _rename(TeamDocument doc) async {
    final controller = TextEditingController(text: doc.docName);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Renombrar documento'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Nuevo nombre'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (ok != true) return;
    final name = controller.text.trim();
    if (name.isEmpty) {
      _snack('El nombre no puede quedar vacío.');
      return;
    }

    setState(() => _busyId = doc.id);
    try {
      await DepartmentDocumentService.rename(doc.id, name);
      _snack('Documento renombrado.');
      await _load();
    } on DocumentException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _delete(TeamDocument doc) async {
    final ok = await showAppConfirmDialog(
      context,
      title: 'Eliminar documento',
      message: '¿Eliminar "${doc.docName}"? Esta acción no se puede deshacer.',
      confirmLabel: 'Eliminar',
      danger: true,
    );
    if (ok != true) return;

    setState(() => _busyId = doc.id);
    try {
      await DepartmentDocumentService.delete(doc.id);
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
        title: Text(widget.departmentName == null
            ? 'Documentos del departamento'
            : 'Documentos · ${widget.departmentName}'),
        automaticallyImplyLeading: true,
      ),
      floatingActionButton: widget.canManage
          ? FloatingActionButton.extended(
              onPressed: _uploading ? null : _pickAndUpload,
              icon: _uploading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_file_rounded),
              label: Text(_uploading ? 'Subiendo…' : 'Subir'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
            child: AppTextField(
              controller: _searchController,
              hintText: 'Buscar documentos por nombre…',
              prefixIcon:
                  Icon(Icons.search_rounded, color: AppColors.textMuted),
            ),
          ),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_loading) return const LoadingState();
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);
    if (_documents.isEmpty) {
      return EmptyState(
        icon: Icons.folder_open_outlined,
        title: 'Aún no hay documentos',
        message: widget.canManage
            ? 'Toca "Subir" para compartir un archivo con el departamento.'
            : 'Cuando el director o el manager suban archivos, aparecerán aquí.',
      );
    }
    final items = _filtered;
    if (items.isEmpty) {
      return EmptyState(
        icon: Icons.search_off_rounded,
        title: 'Sin resultados',
        message: 'Ningún documento coincide con "$_query".',
      );
    }
    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxl),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) => _DocumentCard(
          doc: items[index],
          canManage: widget.canManage,
          busy: _busyId == items[index].id,
          opening: _openingId == items[index].id,
          onOpen: () => _open(items[index]),
          onDownload: () => _download(items[index]),
          onRename: () => _rename(items[index]),
          onDelete: () => _delete(items[index]),
        ),
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({
    required this.doc,
    required this.canManage,
    required this.busy,
    required this.opening,
    required this.onOpen,
    required this.onDownload,
    required this.onRename,
    required this.onDelete,
  });

  final TeamDocument doc;
  final bool canManage;
  final bool busy;
  final bool opening;
  final VoidCallback onOpen;
  final VoidCallback onDownload;
  final VoidCallback onRename;
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
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  meta,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
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
            if (canManage)
              PopupMenuButton<String>(
                tooltip: 'Más acciones',
                icon: Icon(Icons.more_vert_rounded,
                    size: 20, color: AppColors.textMuted),
                onSelected: (v) {
                  if (v == 'rename') onRename();
                  if (v == 'delete') onDelete();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'rename', child: Text('Renombrar')),
                  PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                ],
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
