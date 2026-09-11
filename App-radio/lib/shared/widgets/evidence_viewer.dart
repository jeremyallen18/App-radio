import 'package:flutter/material.dart';

import 'package:doliv_social/core/session_keys.dart' show secureStorage, key;
import 'package:doliv_social/design/design.dart';

/// Visor genérico de una evidencia servida por un endpoint autenticado
/// (nunca una URL pública). Lo usan permisos (`/leave-requests/{id}/evidence`)
/// y tareas (`/dept-tasks/{id}/evidence`): se le pasa la URL ya construida.
class EvidenceViewer extends StatefulWidget {
  const EvidenceViewer(
      {super.key, required this.url, this.title = 'Evidencia'});

  final String url;
  final String title;

  @override
  State<EvidenceViewer> createState() => _EvidenceViewerState();
}

class _EvidenceViewerState extends State<EvidenceViewer> {
  Map<String, String>? _headers;

  @override
  void initState() {
    super.initState();
    secureStorage.readSecureData(key).then((token) {
      if (mounted) {
        setState(() => _headers = {'Authorization': token ?? ''});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(widget.title),
      ),
      body: Center(
        child: _headers == null
            ? const LoadingState()
            : InteractiveViewer(
                maxScale: 5,
                child: Image.network(
                  widget.url,
                  headers: _headers,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) =>
                      progress == null ? child : const LoadingState(),
                  errorBuilder: (context, error, stack) => const Padding(
                    padding: EdgeInsets.all(AppSpacing.xl),
                    child: EmptyState(
                      icon: Icons.broken_image_outlined,
                      title: 'No se pudo cargar la evidencia',
                      message:
                          'Si el archivo es un PDF, ábrelo desde un dispositivo con visor de PDF.',
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
