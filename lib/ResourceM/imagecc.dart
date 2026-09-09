import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../utils/api_config.dart';
import '../screens/login.dart';
import '../design/design.dart';
import 'resource_header.dart';

/// Pantalla "Recursos de imágenes": galería de imágenes del equipo con un
/// FAB (+) en la esquina para subir una nueva imagen directamente desde aquí.
class ImageListScreen extends StatefulWidget {
  final String teamId;
  const ImageListScreen(this.teamId, {super.key});

  @override
  _ImageListScreenState createState() => _ImageListScreenState();
}

class _ImageListScreenState extends State<ImageListScreen> {
  List<Map<String, String>> images = [];
  bool isLoading = true;
  bool hasError = false;

  // Upload state
  final picker = ImagePicker();
  File? _selectedImage;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  bool _uploading = false;

  // Modo de borrado: se activa desde el botón "-" del selector 📷. Mientras
  // está activo, la grilla muestra un distintivo "-" arriba a la derecha de
  // cada miniatura y tocar una imagen la borra (con confirmación) en vez de
  // abrirla a pantalla completa.
  bool _deleteMode = false;
  String? _deletingId;

  void _toggleDeleteMode(bool value) {
    setState(() {
      _deleteMode = value;
      _deletingId = null;
    });
  }

  Future<void> _confirmAndDeleteImage(Map<String, String> image) async {
    final id = image['imgId'];
    if (id == null || id.isEmpty) {
      _showSnack('No se pudo identificar la imagen (backend desactualizado).');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Eliminar imagen', style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          '¿Seguro que quieres eliminar "${image['imgName'] ?? 'esta imagen'}"? Esta acción no se puede deshacer.',
          style: TextStyle(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Eliminar', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _deletingId = id);
    try {
      final storedValue = await secureStorage.readSecureData(key);
      final response = await http.delete(
        Uri.parse('$kBaseUrl/image/$id'),
        headers: {'Authorization': storedValue ?? ''},
      );
      if (response.statusCode == 200) {
        _showSnack('Imagen eliminada.');
        setState(() {
          images.removeWhere((img) => img['imgId'] == id);
          _deleteMode = false;
        });
      } else {
        _showSnack('No se pudo eliminar la imagen (código ${response.statusCode}).');
      }
    } catch (_) {
      _showSnack('Error de red al eliminar la imagen.');
    } finally {
      if (mounted) setState(() => _deletingId = null);
    }
  }

  /// Menú del botón 📷: "+" para subir (comportamiento de siempre) o "-"
  /// para entrar al modo de borrado sobre esta misma grilla.
  void _showCameraMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.lg,
              horizontal: AppSpacing.lg,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _CameraMenuOption(
                  icon: Icons.add_rounded,
                  label: 'Agregar',
                  color: AppColors.success,
                  onTap: () {
                    Navigator.pop(context);
                    _showUploadSheet();
                  },
                ),
                _CameraMenuOption(
                  icon: Icons.remove_rounded,
                  label: 'Eliminar',
                  color: AppColors.error,
                  onTap: () {
                    Navigator.pop(context);
                    _toggleDeleteMode(true);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    getImage();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> getImage() async {
    setState(() {
      isLoading = true;
      hasError = false;
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
        setState(() {
          images = responseData
              .map<Map<String, String>>((item) => {
                    'imgURL': item['imgURL'],
                    'imgName': item['imgName'],
                    // Puede no venir en respuestas de un backend viejo
                    // (antes de la migración 010); se cae de vuelta a ''.
                    'imgDescription': item['imgDescription'] ?? '',
                    // 'imgId' tampoco viene de un backend anterior al
                    // endpoint de borrado; sin él, no se puede eliminar esa
                    // imagen puntual (el modo borrado lo avisa por imagen).
                    'imgId': (item['imgId'] ?? '').toString(),
                  })
              .toList();
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
          hasError = true;
        });
      }
    } catch (error) {
      setState(() {
        isLoading = false;
        hasError = true;
      });
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _selectedImage = File(pickedFile.path));
    }
  }

  Future<void> _uploadImage() async {
    if (_selectedImage == null) {
      _showSnack('Selecciona una imagen primero.');
      return;
    }
    setState(() => _uploading = true);
    try {
      String storedValue = await secureStorage.readSecureData(key);
      var request = http.MultipartRequest(
          'POST', Uri.parse('$kBaseUrl/image/addImage'));
      request.headers.addAll({'Authorization': storedValue});
      request.fields.addAll({
        'imgName': _nameController.text,
        'imgDescription': _descriptionController.text,
        'teamId': widget.teamId,
      });
      request.files.add(
          await http.MultipartFile.fromPath('photo', _selectedImage!.path));

      var response = await request.send();
      if (response.statusCode == 200) {
        _showSnack('Imagen publicada con éxito.');
        Navigator.pop(context); // cierra el bottom sheet
        setState(() {
          _selectedImage = null;
          _nameController.clear();
          _descriptionController.clear();
        });
        getImage();
      } else {
        _showSnack(
            'No se pudo subir la imagen (código ${response.statusCode}).');
      }
    } catch (e) {
      _showSnack('Ocurrió un error al subir la imagen.');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _showUploadSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                top: AppSpacing.lg,
                left: AppSpacing.lg,
                right: AppSpacing.lg,
                bottom: MediaQuery.of(context).viewInsets.bottom +
                    AppSpacing.xl,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceBorder,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Subir imagen nueva',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Selecciona una imagen de tu galería para compartirla con el equipo.',
                    style:
                        TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  // Vista previa
                  GestureDetector(
                    onTap: () async {
                      await _pickImage();
                      setSheetState(() {});
                    },
                    child: Container(
                      height: 180,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.bgBase,
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        border: Border.all(
                          color: _selectedImage != null
                              ? AppColors.accent
                              : AppColors.surfaceBorder,
                          width: _selectedImage != null ? 2 : 1,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _selectedImage != null
                          ? Image.file(_selectedImage!,
                              fit: BoxFit.cover)
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: AppColors.accent
                                        .withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.add_photo_alternate_outlined,
                                    color: AppColors.accent,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  'Toca para elegir imagen',
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  // Nombre
                  AppTextField(
                    controller: _nameController,
                    hintText: 'Nombre de la imagen (opcional)',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  // Descripción: se muestra debajo del nombre al abrir la
                  // imagen (ver ImageDetailScreen), y también desaparece y
                  // aparece junto con él al tocar la imagen.
                  AppTextField(
                    controller: _descriptionController,
                    hintText: 'Descripción (opcional)',
                    maxLines: 3,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  // Botones
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await _pickImage();
                            setSheetState(() {});
                          },
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('Elegir'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: AppButton(
                          label: 'Subir',
                          height: 48,
                          loading: _uploading,
                          onPressed: _uploading
                              ? null
                              : () async {
                                  await _uploadImage();
                                  setSheetState(() {});
                                },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      body: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ResourceHeader(
                title: 'Imágenes',
                subtitle: _deleteMode
                    ? 'Toca una imagen para eliminarla.'
                    : 'Explora las imágenes que el equipo compartió.',
              ),
              if (_deleteMode)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => _toggleDeleteMode(false),
                      icon: Icon(Icons.close_rounded, color: AppColors.error),
                      label: Text('Salir del modo eliminar',
                          style: TextStyle(color: AppColors.error)),
                    ),
                  ),
                ),
              Expanded(
                child: isLoading
                    ? const LoadingState(message: 'Cargando imágenes...')
                    : hasError
                        ? ErrorState(onRetry: getImage)
                        : images.isEmpty
                            ? const EmptyState(
                                icon: Icons.image_outlined,
                                title: 'Todavía no hay imágenes',
                                message:
                                    'Toca el botón + para subir la primera.',
                              )
                            : RefreshIndicator(
                                onRefresh: getImage,
                                child: GridView.builder(
                                  padding: const EdgeInsets.only(
                                      bottom: 96, // espacio para el FAB
                                      left: AppSpacing.md,
                                      right: AppSpacing.md),
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: AppSpacing.md,
                                    mainAxisSpacing: AppSpacing.md,
                                    childAspectRatio: 0.95,
                                  ),
                                  itemCount: images.length,
                                  itemBuilder: (context, index) {
                                    final image = images[index];
                                    final isDeletingThis =
                                        _deletingId == image['imgId'];
                                    return GestureDetector(
                                      onTap: () {
                                        if (_deleteMode) {
                                          _confirmAndDeleteImage(image);
                                          return;
                                        }
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                ImageDetailScreen(
                                              imageUrl: image['imgURL']!,
                                              imageName:
                                                  image['imgName'] ?? '',
                                              imageDescription:
                                                  image['imgDescription'] ?? '',
                                            ),
                                          ),
                                        );
                                      },
                                      child: Stack(
                                        children: [
                                          Container(
                                            clipBehavior: Clip.antiAlias,
                                            decoration: BoxDecoration(
                                              color: AppColors.surface,
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      AppRadius.card),
                                              border: Border.all(
                                                color: _deleteMode
                                                    ? AppColors.error
                                                    : AppColors.surfaceBorder,
                                                width: _deleteMode ? 1.5 : 1,
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: [
                                                Expanded(
                                                  child: Opacity(
                                                    opacity:
                                                        isDeletingThis ? 0.4 : 1,
                                                    child: Image.network(
                                                      image['imgURL']!,
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (context,
                                                              error,
                                                              stackTrace) =>
                                                          Container(
                                                        color:
                                                            AppColors.bgBase,
                                                        child: Icon(
                                                          Icons
                                                              .broken_image_outlined,
                                                          color: AppColors
                                                              .textMuted,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                if ((image['imgName'] ?? '')
                                                    .isNotEmpty)
                                                  Padding(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal:
                                                          AppSpacing.sm,
                                                      vertical: 6,
                                                    ),
                                                    child: Text(
                                                      image['imgName']!,
                                                      maxLines: 1,
                                                      overflow: TextOverflow
                                                          .ellipsis,
                                                      style: TextStyle(
                                                          color: AppColors
                                                              .textPrimary,
                                                          fontSize: 12),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          // Distintivo "-" en modo borrado,
                                          // arriba a la derecha, como pidió
                                          // el usuario.
                                          if (_deleteMode)
                                            Positioned(
                                              top: 6,
                                              right: 6,
                                              child: Container(
                                                width: 26,
                                                height: 26,
                                                decoration: BoxDecoration(
                                                  color: AppColors.error,
                                                  shape: BoxShape.circle,
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black
                                                          .withValues(
                                                              alpha: 0.3),
                                                      blurRadius: 4,
                                                    ),
                                                  ],
                                                ),
                                                child: isDeletingThis
                                                    ? const Padding(
                                                        padding:
                                                            EdgeInsets.all(5),
                                                        child:
                                                            CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          color: Colors.white,
                                                        ),
                                                      )
                                                    : const Icon(
                                                        Icons.remove_rounded,
                                                        color: Colors.white,
                                                        size: 18,
                                                      ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
              ),
            ],
          ),
          // FAB en esquina inferior derecha: si no está en modo borrado,
          // abre el menú 📷 (Agregar / Eliminar); en modo borrado no hace
          // falta, ya hay un botón para salir arriba.
          if (!_deleteMode)
            Positioned(
              bottom: AppSpacing.xl,
              right: AppSpacing.lg,
              child: _CameraFab(onPressed: _showCameraMenu),
            ),
        ],
      ),
    );
  }
}

/// FAB "📷" con gradiente de la marca: reemplaza al "+" simple de antes.
/// Al tocarlo abre un menú con "Agregar" (comportamiento anterior del "+")
/// y "Eliminar" (nuevo modo de borrado sobre la misma grilla).
class _CameraFab extends StatelessWidget {
  const _CameraFab({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          gradient: AppColors.buttonGradient,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.brandNavy.withValues(alpha: 0.4),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: const Icon(Icons.photo_camera_rounded, color: Colors.white, size: 26),
      ),
    );
  }
}

/// Una de las dos opciones (Agregar / Eliminar) del menú del botón 📷.
class _CameraMenuOption extends StatelessWidget {
  const _CameraMenuOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                shape: BoxShape.circle,
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(label, style: TextStyle(color: AppColors.textPrimary, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

/// Pantalla de imagen a pantalla completa. El nombre (arriba) y la
/// descripción (abajo) se muestran como una capa semitransparente sobre la
/// imagen, que aparece y desaparece al tocarla — igual que en apps como
/// Instagram o la galería del teléfono. Junto al nombre, arriba a la
/// derecha, hay un botón para descargar la imagen al dispositivo.
class ImageDetailScreen extends StatefulWidget {
  final String imageUrl;
  final String imageName;
  final String imageDescription;

  const ImageDetailScreen({
    super.key,
    required this.imageUrl,
    this.imageName = '',
    this.imageDescription = '',
  });

  @override
  State<ImageDetailScreen> createState() => _ImageDetailScreenState();
}

class _ImageDetailScreenState extends State<ImageDetailScreen> {
  bool _overlayVisible = true;
  bool _downloading = false;

  void _toggleOverlay() => setState(() => _overlayVisible = !_overlayVisible);

  String _extensionFromUrl(String url) {
    final clean = url.split('?').first;
    final dot = clean.lastIndexOf('.');
    const allowed = {'jpg', 'jpeg', 'png', 'gif', 'webp'};
    if (dot == -1 || dot == clean.length - 1) return 'jpg';
    final ext = clean.substring(dot + 1).toLowerCase();
    return allowed.contains(ext) ? ext : 'jpg';
  }

  Future<void> _downloadImage() async {
    if (_downloading) return;
    setState(() => _downloading = true);
    try {
      final response = await http.get(Uri.parse(widget.imageUrl));
      if (response.statusCode != 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo descargar la imagen (${response.statusCode}).')),
        );
        return;
      }
      final ext = _extensionFromUrl(widget.imageUrl);
      final baseName = widget.imageName.trim().isNotEmpty ? widget.imageName.trim() : 'imagen';
      final fileName = baseName.toLowerCase().endsWith('.$ext') ? baseName : '$baseName.$ext';
      final outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Guardar imagen',
        fileName: fileName,
        bytes: response.bodyBytes,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(outputPath != null ? 'Imagen guardada.' : 'Descarga cancelada.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error de red al descargar la imagen.')),
      );
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasName = widget.imageName.trim().isNotEmpty;
    final hasDescription = widget.imageDescription.trim().isNotEmpty;
    final topInset = MediaQuery.of(context).padding.top;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // La imagen ocupa toda la pantalla; tocarla en cualquier punto
          // muestra/oculta el nombre y la descripción.
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggleOverlay,
            child: Center(
              child: InteractiveViewer(
                child: Image.network(
                  widget.imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white54,
                    size: 64,
                  ),
                ),
              ),
            ),
          ),
          // Barra superior: botón de atrás, nombre y (a su lado, arriba a
          // la derecha) el botón para descargar la imagen.
          AnimatedPositioned(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            top: _overlayVisible ? 0 : -(topInset + 72),
            left: 0,
            right: 0,
            child: IgnorePointer(
              ignoring: !_overlayVisible,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 220),
                opacity: _overlayVisible ? 1 : 0,
                child: Container(
                  padding: EdgeInsets.only(top: topInset, right: AppSpacing.sm),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.8),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                      Expanded(
                        child: Text(
                          hasName ? widget.imageName : 'Imagen',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      _downloading
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          : IconButton(
                              onPressed: _downloadImage,
                              icon: const Icon(Icons.download_rounded, color: Colors.white),
                              tooltip: 'Descargar imagen',
                            ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Barra inferior: descripción, solo si se cargó una. Aparece y
          // desaparece junto con la barra superior.
          if (hasDescription)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              bottom: _overlayVisible ? 0 : -220,
              left: 0,
              right: 0,
              child: IgnorePointer(
                ignoring: !_overlayVisible,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 220),
                  opacity: _overlayVisible ? 1 : 0,
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.only(
                      left: AppSpacing.lg,
                      right: AppSpacing.lg,
                      top: 32,
                      bottom: bottomInset + AppSpacing.lg,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.85),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Text(
                      widget.imageDescription,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}