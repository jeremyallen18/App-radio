import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../design/design.dart';
import '../utils/api_config.dart';
import 'login.dart';

class ChatScreenfetch extends StatefulWidget {
  const ChatScreenfetch({super.key});

  @override
  _ChatScreenfetchState createState() => _ChatScreenfetchState();
}

class _ChatScreenfetchState extends State<ChatScreenfetch> {
  List<Map<String, dynamic>> _chats = [];
  final ScrollController _scrollController = ScrollController();
  bool _loading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    fetchChats();
  }

  Future<void> fetchChats() async {
    setState(() {
      _loading = true;
      _hasError = false;
    });
    final apiUrl = '$kBaseUrl/chat/getAllChats';
    try {
      final token = await secureStorage.readSecureData(key);
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: <String, String>{'Authorization': token ?? ''},
      );
      if (!mounted) return;

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        setState(() {
          _chats = List<Map<String, dynamic>>.from(responseData['chats'] ?? []);
          _loading = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
          }
        });
      } else {
        setState(() {
          _hasError = true;
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      padding: EdgeInsets.zero,
      appBar: AppBar(
        title: const Text('Historial de conversaciones'),
        leading: AppBackButton.leadingFor(context),
        automaticallyImplyLeading: false,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
            );
          }
        },
        child: const Icon(Icons.arrow_downward),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const LoadingState();
    if (_hasError) return ErrorState(onRetry: fetchChats);
    if (_chats.isEmpty) {
      return const EmptyState(
        icon: Icons.forum_outlined,
        title: 'Todavía no hay mensajes',
      );
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      itemCount: _chats.length,
      itemBuilder: (context, index) {
        final chat = _chats[index];
        return ChatBubble(
          username: chat['username']?.toString() ?? '',
          message: chat['message']?.toString() ?? '',
          // Es un historial de solo lectura, sin sesión propia con la que
          // comparar "quién soy yo": todos los mensajes se muestran igual.
          isMe: false,
        );
      },
    );
  }
}
