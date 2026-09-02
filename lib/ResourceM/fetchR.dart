import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../utils/api_config.dart';
import '../screens/login.dart';
import '../design/design.dart';
import 'resource_header.dart';

/// Pantalla "Descargar recursos": muestra los recursos de texto que el
/// equipo publicó (vía "Publicar recursos"), agrupados por quien los
/// escribió. Migrada al sistema de diseño: reemplaza los `Card`/`ListTile`
/// con colores fijos por `AppCard` y agrega estados de carga/vacío
/// coherentes con el resto de la app en vez de un `Text` suelto.
class ShowTextScreen extends StatefulWidget {
  final String teamId;
  const ShowTextScreen(this.teamId, {super.key});

  @override
  _ShowTextScreenState createState() => _ShowTextScreenState();
}

class _ShowTextScreenState extends State<ShowTextScreen> {
  List<dynamic> messages = [];
  bool isLoading = true;
  bool hasError = false;

  Future<void> fetchMessages() async {
    setState(() {
      isLoading = true;
      hasError = false;
    });
    try {
      dynamic storedValue = await secureStorage.readSecureData(key);

      http.Response response = await http.get(
        Uri.parse('$kBaseUrl/text/showText/${widget.teamId}'),
        headers: {
          'Authorization': storedValue ?? '',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);

        setState(() {
          isLoading = false;
          if (responseData['data'] is List) {
            messages = responseData['data'];
          } else {
            hasError = true;
          }
        });
      } else {
        setState(() {
          isLoading = false;
          hasError = true;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        hasError = true;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    fetchMessages();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ResourceHeader(
            title: 'Descargar recursos',
            subtitle: 'Recursos de texto que el equipo ya compartió.',
          ),
          Expanded(
            child: isLoading
                ? const LoadingState(message: 'Cargando recursos...')
                : hasError
                    ? ErrorState(onRetry: fetchMessages)
                    : messages.isEmpty
                        ? const EmptyState(
                            icon: Icons.inbox_outlined,
                            title: 'Todavía no hay recursos',
                            message: 'Cuando alguien publique un recurso de texto, aparecerá aquí.',
                          )
                        : RefreshIndicator(
                            onRefresh: fetchMessages,
                            child: ListView.builder(
                              padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                              reverse: true,
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: messages.length,
                              itemBuilder: (context, index) {
                                final email = messages[index]['email'];
                                final texts = messages[index]['texts'] as List;

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      SectionHeader(
                                        title: email,
                                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                                      ),
                                      ...texts.map(
                                        (t) => Padding(
                                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                                          child: AppCard(
                                            child: Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Icon(Icons.notes_rounded, color: AppColors.accent, size: 18),
                                                const SizedBox(width: AppSpacing.md),
                                                Expanded(
                                                  child: Text(
                                                    t['text'] ?? '',
                                                    style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
                                                  ),
                                                ),
                                              ],
                                            ),
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
    );
  }
}
