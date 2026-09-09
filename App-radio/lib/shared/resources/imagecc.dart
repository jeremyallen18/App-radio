import 'dart:convert';
import 'package:doliv_social/shared/auth/login.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/core/api_config.dart';

/// Extensión de imagen deducida de una URL (ignora el query string). Se usa
/// para nombrar el archivo al descargarlo. Solo acepta formatos de imagen
/// conocidos; cualquier otra cosa cae a `jpg`.
String imageExtFromUrl(String url) {
  final clean = url.split('?').first;
  final dot = clean.lastIndexOf('.');
  const allowed = {'jpg', 'jpeg', 'png', 'gif', 'webp'};
  if (dot == -1 || dot == clean.length - 1) return 'jpg';
  final ext = clean.substring(dot + 1).toLowerCase();
  return allowed.contains(ext) ? ext : 'jpg';
}

/// Placeholder para una imagen que no se pudo cargar (URL rota, archivo
/// borrado en el servidor, sin conexión). Evita el recuadro rojo de excepción
/// que muestra `Image.network` por defecto.
class _BrokenImage extends StatelessWidget {
  const _BrokenImage({this.large = false});
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: large ? Colors.black : AppColors.bgBase,
      alignment: Alignment.center,
      child: Icon(
        Icons.broken_image_outlined,
        color: large ? Colors.white54 : AppColors.textMuted,
        size: large ? 64 : 28,
      ),
    );
  }
}

class ImageListScreen extends StatefulWidget {
  final String teamId;
  const ImageListScreen(this.teamId, {super.key});

  @override
  State<ImageListScreen> createState() => _ImageListScreenState();
}

class _ImageListScreenState extends State<ImageListScreen> {
  List<Map<String, String>> images = [];
  bool isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    getImage();
  }

  Future<void> getImage() async {
    setState(() {
      isLoading = true;
      _hasError = false;
    });
    dynamic storedValue = await secureStorage.readSecureData(key);
    String url = '$kBaseUrl/image/showImage/${widget.teamId}';
    String token = storedValue;

    try {
      http.Response response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': token,
        },
      );

      if (response.statusCode == 200) {
        List<dynamic> responseData = json.decode(response.body);
        if (!mounted) return;
        setState(() {
          images = responseData.map<Map<String, String>>((item) {
            return {
              'imgURL': (item['imgURL'] ?? '').toString(),
              'imgName': (item['imgName'] ?? '').toString(),
            };
          }).toList();
          isLoading = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _hasError = true;
          isLoading = false;
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      padding: EdgeInsets.zero,
      appBar: AppBar(
        title: const Text('Recursos de imágenes'),
        automaticallyImplyLeading: false,
      ),
      body: isLoading
          ? const LoadingState()
          : _hasError
              ? ErrorState(
                  message: 'No se pudieron cargar las imágenes.',
                  onRetry: getImage,
                )
              : images.isEmpty
                  ? EmptyState(
                      icon: Icons.image_outlined,
                      title: 'Todavía no hay imágenes',
                      message:
                          'Las imágenes que se publiquen para este equipo aparecerán aquí.',
                      action: OutlinedButton(
                        onPressed: getImage,
                        child: const Text('Actualizar'),
                      ),
                    )
                  // El ancho disponible decide cuántas columnas entran (2 en
                  // vertical, más en horizontal), sin estirar las imágenes.
                  : RefreshIndicator(
                      color: AppColors.accent,
                      onRefresh: getImage,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final int crossAxisCount =
                              (constraints.maxWidth / 180).floor().clamp(2, 6);
                          return GridView.builder(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              crossAxisSpacing: AppSpacing.sm,
                              mainAxisSpacing: AppSpacing.sm,
                            ),
                            itemCount: images.length,
                            itemBuilder: (context, index) {
                              final img = images[index];
                              return GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ImageDetailScreen(
                                        imageUrl: img['imgURL']!,
                                        imageName: img['imgName'] ?? '',
                                      ),
                                    ),
                                  );
                                },
                                child: ClipRRect(
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.card),
                                  child: Image.network(
                                    img['imgURL']!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        const _BrokenImage(),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
    );
  }
}

/// Visor de una imagen del equipo a pantalla completa, con un botón para
/// descargarla al dispositivo.
class ImageDetailScreen extends StatefulWidget {
  final String imageUrl;
  final String imageName;

  const ImageDetailScreen({
    super.key,
    required this.imageUrl,
    this.imageName = '',
  });

  @override
  State<ImageDetailScreen> createState() => _ImageDetailScreenState();
}

class _ImageDetailScreenState extends State<ImageDetailScreen> {
  bool _downloading = false;

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _download() async {
    if (_downloading) return;
    setState(() => _downloading = true);
    try {
      final res = await http.get(Uri.parse(widget.imageUrl));
      if (res.statusCode != 200) {
        _snack('No se pudo descargar la imagen (${res.statusCode}).');
        return;
      }
      final ext = imageExtFromUrl(widget.imageUrl);
      final base = widget.imageName.trim().isNotEmpty
          ? widget.imageName.trim()
          : 'imagen';
      final fileName =
          base.toLowerCase().endsWith('.$ext') ? base : '$base.$ext';
      final Uri? saved = await FilePicker.saveFile(
        dialogTitle: 'Guardar imagen',
        fileName: fileName,
        bytes: res.bodyBytes,
        mimeType: 'image/$ext',
      );
      _snack(saved != null ? 'Imagen guardada.' : 'Descarga cancelada.');
    } catch (_) {
      _snack('Error de red al descargar la imagen.');
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      padding: EdgeInsets.zero,
      appBar: AppBar(
        title: Text(widget.imageName.trim().isNotEmpty
            ? widget.imageName.trim()
            : 'Imagen'),
        automaticallyImplyLeading: false,
        actions: [
          _downloading
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(
                  tooltip: 'Descargar imagen',
                  onPressed: _download,
                  icon: const Icon(Icons.download_rounded),
                ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.network(
            widget.imageUrl,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const _BrokenImage(large: true),
          ),
        ),
      ),
    );
  }
}
