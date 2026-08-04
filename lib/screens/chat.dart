import 'dart:async';
import 'dart:convert';
import 'package:brl_task4/screens/chatHistory.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../design/design.dart';
import '../utils/api_config.dart';
import 'login.dart';

class ChatScreen extends StatefulWidget {
  final String name;

  const ChatScreen(this.name, {super.key});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  final ScrollController _scrollController = ScrollController();
  late String myUsername;
  Timer? _pollTimer;
  bool _loading = true;

  static const String _chatApiUrl = '$kBaseUrl/chat/getAllChats';
  static const String _sendApiUrl = '$kBaseUrl/chat/sendMessage';

  @override
  void initState() {
    super.initState();
    myUsername = widget.name;
    _fetchMessages();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _fetchMessages());
  }

  Future<void> _fetchMessages() async {
    try {
      final token = await secureStorage.readSecureData(key);
      final response = await http.get(
        Uri.parse(_chatApiUrl),
        headers: <String, String>{'Authorization': token ?? ''},
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final List<dynamic> chats = decoded['chats'] ?? [];
        final bool wasAtBottom = _isNearBottom();
        setState(() {
          _messages
            ..clear()
            ..addAll(chats.map((c) => {
                  'message': c['message'],
                  'username': c['username'],
                }));
          _loading = false;
        });
        if (wasAtBottom) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
        }
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _isNearBottom() {
    if (!_scrollController.hasClients) return true;
    final pos = _scrollController.position;
    return pos.maxScrollExtent - pos.pixels < 120;
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();
    try {
      final token = await secureStorage.readSecureData(key);
      final response = await http.post(
        Uri.parse(_sendApiUrl),
        headers: <String, String>{'Authorization': token ?? ''},
        body: {'message': text},
      );
      if (response.statusCode == 200) {
        await _fetchMessages();
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo enviar el mensaje')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error de red al enviar el mensaje')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      padding: EdgeInsets.zero,
      safeArea: false,
      appBar: AppBar(
        title: const Text('Chat'),
        actions: [
          IconButton(
            tooltip: 'Historial',
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreenfetch()));
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SafeArea(
              bottom: false,
              child: _loading
                  ? const LoadingState()
                  : _messages.isEmpty
                      ? const EmptyState(
                          icon: Icons.forum_outlined,
                          title: 'Todavía no hay mensajes',
                          message: 'Sé el primero en escribir algo.',
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final message = _messages[index]['message']?.toString() ?? '';
                            final username = _messages[index]['username']?.toString() ?? '';
                            return ChatBubble(
                              username: username,
                              message: message,
                              isMe: username == myUsername,
                            );
                          },
                        ),
            ),
          ),
          MessageComposer(controller: _controller, onSend: _sendMessage),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }
}
