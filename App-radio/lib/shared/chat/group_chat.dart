import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/core/api_config.dart';
import 'package:doliv_social/core/push/push_service.dart';
import 'package:doliv_social/shared/auth/login.dart';

/// Chat grupal: uno para toda la empresa y uno por departamento (ver
/// `hive-backend/chat_groups.php`). Calco de [ChatScreen] (1 a 1), con la
/// diferencia de que cada burbuja muestra el nombre real de quien escribió
/// en vez de un único `peerName`.
class GroupChatScreen extends StatefulWidget {
  final String groupId;

  const GroupChatScreen({super.key, required this.groupId});

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _inputFocus = FocusNode();
  final List<Map<String, dynamic>> _messages = [];
  final ScrollController _scrollController = ScrollController();
  Timer? _pollTimer;
  bool _loading = true;
  bool _sending = false;
  bool _emojiOpen = false;
  String _groupName = '';

  String get _threadUrl => '$kBaseUrl/chat/group/${widget.groupId}/thread';
  String get _sendUrl => '$kBaseUrl/chat/group/${widget.groupId}/sendMessage';

  @override
  void initState() {
    super.initState();
    PushService.instance.setActiveChatGroup(widget.groupId);
    _inputFocus.addListener(() {
      if (_inputFocus.hasFocus && _emojiOpen) {
        setState(() => _emojiOpen = false);
      }
    });
    _fetchMessages();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      final isCurrent = ModalRoute.of(context)?.isCurrent ?? true;
      if (isCurrent) _fetchMessages();
    });
  }

  Future<void> _fetchMessages() async {
    try {
      final token = await secureStorage.readSecureData(key);
      final response = await http.get(
        Uri.parse(_threadUrl),
        headers: <String, String>{'Authorization': token ?? ''},
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final List<dynamic> msgs = decoded['messages'] ?? [];
        final group = decoded['group'] as Map<String, dynamic>?;
        final bool wasAtBottom = _isNearBottom();
        setState(() {
          if (group != null && (group['name']?.toString().isNotEmpty ?? false)) {
            _groupName = group['name'].toString();
          }
          _messages
            ..clear()
            ..addAll(msgs.map((m) => {
                  'message': m['message'],
                  'senderName': m['senderName'],
                  'fromMe': m['fromMe'] == true,
                  'createdAt':
                      DateTime.tryParse('${m['createdAt']}')?.toLocal(),
                }));
          _loading = false;
        });
        if (wasAtBottom) {
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _scrollToBottom());
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
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    _controller.clear();
    try {
      final token = await secureStorage.readSecureData(key);
      final response = await http.post(
        Uri.parse(_sendUrl),
        headers: <String, String>{'Authorization': token ?? ''},
        body: {'message': text},
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        await _fetchMessages();
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      } else {
        _controller.text = text;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo enviar el mensaje')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      _controller.text = text;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error de red al enviar el mensaje')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _toggleEmoji() {
    if (_emojiOpen) {
      setState(() => _emojiOpen = false);
      _inputFocus.requestFocus();
    } else {
      _inputFocus.unfocus();
      setState(() => _emojiOpen = true);
    }
  }

  void _insertEmoji(String emoji) {
    final sel = _controller.selection;
    final text = _controller.text;
    if (sel.isValid && sel.start >= 0) {
      final newText = text.replaceRange(sel.start, sel.end, emoji);
      _controller.value = TextEditingValue(
        text: newText,
        selection:
            TextSelection.collapsed(offset: sel.start + emoji.length),
      );
    } else {
      _controller.text = text + emoji;
    }
  }

  List<Widget> _chatRows() {
    final rows = <Widget>[];
    DateTime? prevDay;
    for (final m in _messages) {
      final createdAt = m['createdAt'] as DateTime?;
      if (createdAt != null) {
        final day = DateTime(createdAt.year, createdAt.month, createdAt.day);
        if (prevDay == null || day != prevDay) {
          rows.add(DayDivider(label: DayDivider.labelForDate(createdAt)));
          prevDay = day;
        }
      }
      final fromMe = m['fromMe'] == true;
      rows.add(ChatBubble(
        username: fromMe ? 'Tú' : (m['senderName']?.toString() ?? ''),
        message: m['message']?.toString() ?? '',
        isMe: fromMe,
      ));
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      padding: EdgeInsets.zero,
      safeArea: false,
      appBar: AppBar(
        title: Text(_groupName.isNotEmpty ? _groupName : 'Chat de grupo'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          Expanded(
            child: SafeArea(
              bottom: false,
              child: _loading
                  ? const LoadingState()
                  : _messages.isEmpty
                      ? EmptyState(
                          icon: Icons.groups_outlined,
                          title: 'Todavía no hay mensajes',
                          message: 'Escribe algo para empezar la conversación.',
                        )
                      : ListView(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.md),
                          children: _chatRows(),
                        ),
            ),
          ),
          MessageComposer(
            controller: _controller,
            focusNode: _inputFocus,
            onSend: _sendMessage,
            emojiActive: _emojiOpen,
            onToggleEmoji: _toggleEmoji,
          ),
          if (_emojiOpen)
            EmojiPickerPanel(onEmojiSelected: _insertEmoji),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _scrollController.dispose();
    _controller.dispose();
    _inputFocus.dispose();
    PushService.instance.setActiveChatGroup(null);
    super.dispose();
  }
}
