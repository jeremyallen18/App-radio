import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../utils/api_config.dart';
import '../screens/login.dart';
import '../design/design.dart';
import 'resource_header.dart';

/// Pantalla "Recursos de imágenes": galería de las imágenes que el equipo
/// subió. Migrada al sistema de diseño: usa `ResourceHeader`, `LoadingState`
/// /`EmptyState`/`ErrorState` y tarjetas con el radio/borde estándar en vez
/// del `AppBar` y el `GridView` con estilos sueltos que tenía antes.
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

  @override
  void initState() {
    super.initState();
    getImage();
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

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ResourceHeader(
            title: 'Recursos de imágenes',
            subtitle: 'Explora las imágenes que el equipo compartió.',
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
                            message: 'Publica una desde "Publicar recursos" y aparecerá aquí.',
                          )
                        : RefreshIndicator(
                            onRefresh: getImage,
                            child: GridView.builder(
                              padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                              physics: const AlwaysScrollableScrollPhysics(),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: AppSpacing.md,
                                mainAxisSpacing: AppSpacing.md,
                                childAspectRatio: 0.95,
                              ),
                              itemCount: images.length,
                              itemBuilder: (context, index) {
                                final image = images[index];
                                return GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ImageDetailScreen(
                                          imageUrl: image['imgURL']!,
                                          imageName: image['imgName'] ?? '',
                                        ),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    clipBehavior: Clip.antiAlias,
                                    decoration: BoxDecoration(
                                      color: AppColors.surface,
                                      borderRadius: BorderRadius.circular(AppRadius.card),
                                      border: Border.all(color: AppColors.surfaceBorder),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Expanded(
                                          child: Image.network(
                                            image['imgURL']!,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) => Container(
                                              color: AppColors.bgBase,
                                              child: Icon(Icons.broken_image_outlined, color: AppColors.textMuted),
                                            ),
                                          ),
                                        ),
                                        if ((image['imgName'] ?? '').isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: AppSpacing.sm,
                                              vertical: 6,
                                            ),
                                            child: Text(
                                              image['imgName']!,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(color: AppColors.textPrimary, fontSize: 12),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
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

class ImageDetailScreen extends StatelessWidget {
  final String imageUrl;
  final String imageName;

  const ImageDetailScreen({super.key, required this.imageUrl, this.imageName = ''});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        foregroundColor: Colors.white,
        title: Text(imageName.isEmpty ? 'Imagen' : imageName),
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
