import 'dart:convert';
import 'package:doliv_social/screens/login.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../utils/api_config.dart';
import '../design/design.dart';

class ShowTextScreen extends StatefulWidget {
  final String teamId;
  const ShowTextScreen(this.teamId, {super.key});

  @override
  _ShowTextScreenState createState() => _ShowTextScreenState();
}

class _ShowTextScreenState extends State<ShowTextScreen> {
  List<dynamic> messages = [];
  bool isLoading = true;
  List<Map<String, String>> images = [];
  bool isLoadingm = true;


 Future<void> getImage() async {
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
        images = responseData.map<Map<String, String>>((item) => {
          'imgURL': item['imgURL'],
          'imgName': item['imgName'],
        }).toList();
        isLoading = false;
      });
    } else {
      
      print('Failed to retrieve the image. Status code: ${response.statusCode}');
    }
  } catch (error) {
  
    print('Error: $error');
  }
}
 
  Future<void> fetchMessages() async {
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
            print('Invalid data structure');
          }
        });
      } else {
        print('Failed to fetch messages. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching messages: $e');
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
      appBar: AppBar(
        title: const Text('Recursos publicados'),
        leading: AppBackButton.leadingFor(context),
        automaticallyImplyLeading: false,
      ),
      padding: EdgeInsets.zero,
      body: isLoading
          ? const LoadingState()
          : messages.isEmpty
              ? const EmptyState(
                  icon: Icons.inbox_outlined,
                  title: 'No hay recursos publicados todavía',
                  message: 'Los textos que publique el equipo aparecerán aquí.',
                )
              : RefreshIndicator(
                  onRefresh: fetchMessages,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.lg),
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
                            Row(
                              children: [
                                const Icon(Icons.person_outline, size: 16, color: AppColors.textMuted),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '$email',
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            for (int i = 0; i < texts.length; i++)
                              Padding(
                                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                                child: AppCard(
                                  padding: const EdgeInsets.all(AppSpacing.md),
                                  child: Text(
                                    texts[i]['text'] ?? '',
                                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}


