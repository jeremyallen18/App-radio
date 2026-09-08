import 'dart:convert';
import 'package:doliv_social/shared/auth/login.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/core/api_config.dart';

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
        images = responseData.map<Map<String, String>>((item) => {
          'imgURL': item['imgURL'],
          'imgName': item['imgName'],
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
                      message: 'Las imágenes que se publiquen para este equipo aparecerán aquí.',
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
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              crossAxisSpacing: AppSpacing.sm,
                              mainAxisSpacing: AppSpacing.sm,
                            ),
                            itemCount: images.length,
                            itemBuilder: (context, index) {
                              return GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ImageDetailScreen(
                                        imageUrl: images[index]['imgURL']!,
                                      ),
                                    ),
                                  );
                                },
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(AppRadius.card),
                                  child: Image.network(
                                    images[index]['imgURL']!,
                                    fit: BoxFit.cover,
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

class ImageDetailScreen extends StatelessWidget {
  final String imageUrl;

  const ImageDetailScreen({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      padding: EdgeInsets.zero,
      appBar: AppBar(
        title: const Text('Imagen'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Image.network(
          imageUrl,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

