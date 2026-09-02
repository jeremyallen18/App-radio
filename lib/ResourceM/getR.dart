import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../utils/api_config.dart';
import '../screens/login.dart';
import '../design/design.dart';
import 'resource_header.dart';

/// Pantalla "Publicar recursos": redactar un recurso de texto y, aparte,
/// subir una imagen suelta para el equipo. Migrada al sistema de diseño:
/// dos `AppCard` (uno por tipo de recurso) con `AppTextField`/`AppButton`
/// en vez de los campos y botones con colores fijos que tenía antes.
class PostTextScreen extends StatefulWidget {
  final String teamId;
  const PostTextScreen(this.teamId, {super.key});

  @override
  _PostTextScreenState createState() => _PostTextScreenState();
}

class _PostTextScreenState extends State<PostTextScreen> {
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _imageController = TextEditingController();
  final picker = ImagePicker();
  File? _image;
  bool _postingText = false;
  bool _postingImage = false;

  Future getImageGallery() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    setState(() {
      if (pickedFile != null) {
        _image = File(pickedFile.path);
      }
    });
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> postImage() async {
    if (_image == null) {
      _showSnack('Selecciona una imagen primero.');
      return;
    }
    setState(() => _postingImage = true);
    try {
      String storedValue = await secureStorage.readSecureData(key);
      var apiUrl = '$kBaseUrl/image/addImage';
      var request = http.MultipartRequest('POST', Uri.parse(apiUrl));
      request.headers.addAll({'Authorization': storedValue});
      request.fields.addAll({
        'imgName': _imageController.text,
        'teamId': widget.teamId,
      });
      request.files.add(await http.MultipartFile.fromPath('photo', _image!.path));

      var response = await request.send();
      if (response.statusCode == 200) {
        _showSnack('Imagen publicada con éxito.');
      } else {
        _showSnack('No se pudo subir la imagen (código ${response.statusCode}).');
      }
    } catch (e) {
      _showSnack('Ocurrió un error al subir la imagen.');
    } finally {
      if (mounted) {
        setState(() {
          _postingImage = false;
          _image = null;
          _imageController.clear();
        });
      }
    }
  }

  Future<void> postText() async {
    if (_textController.text.trim().isEmpty) {
      _showSnack('Escribe algo antes de publicar.');
      return;
    }
    setState(() => _postingText = true);
    try {
      String storedValue = await secureStorage.readSecureData(key);
      var headers = {
        'Authorization': storedValue,
        'Content-Type': 'application/json',
      };
      var request = http.Request(
        'POST',
        Uri.parse('$kBaseUrl/text/addText/${widget.teamId}'),
      );
      request.body = json.encode({"text": _textController.text});
      request.headers.addAll(headers);

      http.StreamedResponse response = await request.send();

      // El backend PHP responde 201 y el de Node 200; ambos significan que
      // el texto se guardó.
      if (response.statusCode == 200 || response.statusCode == 201) {
        _showSnack('Recurso publicado con éxito.');
        _textController.clear();
      } else {
        _showSnack('Error al publicar el texto (código ${response.statusCode}).');
      }
    } catch (e) {
      _showSnack('Ocurrió un error al publicar el texto.');
    } finally {
      if (mounted) setState(() => _postingText = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ResourceHeader(
            title: 'Publicar recursos',
            subtitle: 'Comparte texto o una imagen con tu equipo.',
          ),
          SectionHeader(
            title: 'Recurso de texto',
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          ),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppTextField(
                  controller: _textController,
                  hintText: 'Publica tus recursos...',
                  maxLines: 5,
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'Publicar texto',
                  loading: _postingText,
                  onPressed: _postingText ? null : postText,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SectionHeader(
            title: 'Imagen suelta',
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          ),
          AppCard(
            child: Column(
              children: [
                AppTextField(
                  controller: _imageController,
                  hintText: 'Nombre de la imagen',
                ),
                const SizedBox(height: AppSpacing.md),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.field),
                  child: _image != null
                      ? Image.file(_image!, height: 160, width: double.infinity, fit: BoxFit.cover)
                      : Container(
                          height: 160,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: AppColors.bgBase,
                            borderRadius: BorderRadius.circular(AppRadius.field),
                            border: Border.all(color: AppColors.surfaceBorder),
                          ),
                          child: Icon(Icons.image_outlined, color: AppColors.textMuted, size: 36),
                        ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: getImageGallery,
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Elegir imagen'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: AppButton(
                        label: 'Publicar imagen',
                        height: 44,
                        loading: _postingImage,
                        onPressed: _postingImage ? null : postImage,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}
