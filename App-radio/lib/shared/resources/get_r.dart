import 'dart:convert';
import 'dart:io';
import 'package:doliv_social/shared/auth/login.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:doliv_social/core/api_config.dart';
import 'package:doliv_social/design/design.dart';

class PostTextScreen extends StatefulWidget {
  final String teamId;
  const PostTextScreen(this.teamId, {super.key});

  @override
  State<PostTextScreen> createState() => _PostTextScreenState();
}

class _PostTextScreenState extends State<PostTextScreen> {
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _imageController = TextEditingController();
  String _responseMessage = '';
  final picker = ImagePicker();
  File? _image;
  bool _postingText = false;
  bool _postingImage = false;

  Future getImageGallery() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    setState(() {
      if (pickedFile != null) {
        _image = File(pickedFile.path);
      } else {
        debugPrint('No image selected');
      }
    });
  }

  Future<void> postImage() async {
    if (_image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una imagen primero')),
      );
      return;
    }

    setState(() => _postingImage = true);
    final storedValue = await secureStorage.readSecureData(key);
    if (storedValue == null || storedValue.trim().isEmpty) {
      if (mounted) setState(() => _postingImage = false);
      return;
    }
    try {
      var apiUrl = '$kBaseUrl/image/addImage';

      var headers = {
        'Authorization': storedValue,
      };

      var request = http.MultipartRequest('POST', Uri.parse(apiUrl));

      request.headers.addAll(headers);

      request.fields.addAll({
        'imgName': _imageController.text,
        'teamId': widget.teamId,
      });
      debugPrint(widget.teamId);

      request.files
          .add(await http.MultipartFile.fromPath('photo', _image!.path));

      var response = await request.send();
      final String responseBody = await response.stream.bytesToString();

      if (!mounted) return;
      if (response.statusCode == 200) {
        debugPrint('Image uploaded successfully');
        debugPrint(responseBody);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Imagen publicada')),
        );
      } else {
        debugPrint(
            'Failed to upload image. Status code: ${response.statusCode}');
        debugPrint(response.reasonPhrase);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('No se pudo subir la imagen (${response.statusCode})')),
        );
      }
    } catch (e) {
      debugPrint('Error uploading image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error de red al subir la imagen')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _image = null;
          _imageController.clear();
          _postingImage = false;
        });
      }
    }
  }

  Future<void> postText() async {
    if (_textController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe algo para publicar')),
      );
      return;
    }

    setState(() => _postingText = true);
    try {
      final storedValue = await secureStorage.readSecureData(key);
      if (storedValue == null || storedValue.trim().isEmpty) {
        if (mounted) setState(() => _postingText = false);
        return;
      }

      var headers = {
        'Authorization': storedValue,
        'Content-Type': 'application/json',
      };

      var request = http.Request(
          'POST', Uri.parse('$kBaseUrl/text/addText/${widget.teamId}'));
      request.body = json.encode({"text": _textController.text});
      request.headers.addAll(headers);

      http.StreamedResponse response = await request.send();
      final String responseBody = await response.stream.bytesToString();

      if (!mounted) return;
      // El backend PHP responde 201 y el de Node 200; ambos significan que el
      // texto se guardó.
      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> responseData = json.decode(responseBody);
        setState(() {
          _responseMessage = responseData['message'];
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Error al publicar el texto. Código: ${response.statusCode}'),
        ));
      }
    } catch (e) {
      debugPrint('Error posting text: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Ocurrió un error al publicar el texto.'),
      ));
    } finally {
      _textController.clear();
      if (mounted) setState(() => _postingText = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        title: const Text('Publicar recursos'),
        automaticallyImplyLeading: false,
      ),
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader(title: 'Publicar un texto'),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  controller: _textController,
                  prefixIcon:
                      Icon(Icons.notes_outlined, color: AppColors.textMuted),
                  hintText: 'Publica tus recursos',
                  maxLines: 4,
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: _postingText ? 'Publicando…' : 'Publicar texto',
                  loading: _postingText,
                  onPressed: _postingText ? null : postText,
                  height: 46,
                ),
                if (_responseMessage.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _responseMessage,
                    style: TextStyle(color: AppColors.success, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          const SectionHeader(title: 'Publicar una imagen'),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  controller: _imageController,
                  prefixIcon:
                      Icon(Icons.image_outlined, color: AppColors.textMuted),
                  hintText: 'Nombre de la imagen',
                ),
                const SizedBox(height: AppSpacing.md),
                Center(
                  child: _image != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.card),
                          child: Image.file(
                            _image!,
                            height: 150,
                            width: 150,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Container(
                          height: 150,
                          width: 150,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppRadius.card),
                            border: Border.all(color: AppColors.surfaceBorder),
                            color: AppColors.bgBase,
                          ),
                          child: Icon(Icons.image_outlined,
                              color: AppColors.textMuted, size: 32),
                        ),
                ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: getImageGallery,
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: const Text('Elegir imagen'),
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: _postingImage ? 'Publicando…' : 'Publicar imagen',
                  loading: _postingImage,
                  onPressed: _postingImage ? null : postImage,
                  height: 46,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}
