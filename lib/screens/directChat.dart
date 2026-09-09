import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../design/design.dart';
import '../models/message_status.dart';
import '../utils/api_config.dart';
import 'login.dart';

// Mensaje propio pendiente de confirmación del servidor. Se muestra de
// inmediato (estilo WhatsApp) y se elimina cuando el servidor lo devuelve
// en la lista oficial de mensajes.
class _PendingMessage {
  _PendingMessage({
    required this.localId,
    required this.text,
    required this.createdAt,
    this.replyTo,
  });

  final String localId;
  final String text;
  final DateTime createdAt;
  final Map<String, dynamic>? replyTo;
  MessageStatus status = MessageStatus.sending;
}

// Chat privado 1 a 1 entre myEmail y peerEmail.
class DirectChatScreen extends StatefulWidget {
  final String peerEmail;
  final String myEmail;
  final String? peerName;

  const DirectChatScreen({
    super.key,
    required this.peerEmail,
    required this.myEmail,
    this.peerName,
  });

  @override
  State<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends State<DirectChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  final List<_PendingMessage> _pending = [];
  final ScrollController _scrollController = ScrollController();
  Timer? _pollTimer;
  bool _loading = true;
  Map<String, dynamic>? _replyingTo;

  String get _chatApiUrl =>
      '$kBaseUrl/chat/direct?with=${Uri.encodeQueryComponent(widget.peerEmail)}';
  String get _sendApiUrl => '$kBaseUrl/chat/direct';

  @override
  void initState() {
    super.initState();
    _fetchMessages();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _fetchMessages(),
    );
  }

  Future<void> _fetchMessages() async {
    try {
      final token = await secureStorage.readSecureData(key);
      final response = await http.get(
        Uri.parse(_chatApiUrl),
        headers: {'Authorization': token ?? ''},
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final List<dynamic> chats = decoded['chats'] ?? [];
        final wasAtBottom = _isNearBottom();
        setState(() {
          _messages
            ..clear()
            ..addAll(chats.map((c) => {
                  'id': c['id'],
                  'message': c['message'],
                  'username': c['username'],
                  'name': c['name'],
                  'photoUrl': c['photoUrl'],
                  'createdAt': c['createdAt'],
                  'status': c['status'],
                  'replyTo': c['replyTo'],
                }));
          // Eliminar pendientes cuyo texto ya aparece en la lista oficial.
          // Si el servidor aún no devolvió el mensaje, el pending se queda
          // visible hasta el siguiente poll.
          _pending.removeWhere((p) => _messages.any((m) =>
              m['message']?.toString() == p.text &&
              m['username']?.toString() == widget.myEmail));
          _loading = false;
        });
        if (wasAtBottom) {
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _scrollToBottom());
        }
        _markRead();
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markRead() async {
    try {
      final token = await secureStorage.readSecureData(key);
      await http.post(
        Uri.parse('$kBaseUrl/chat/read'),
        headers: {'Authorization': token ?? '', 'Content-Type': 'application/json'},
        body: jsonEncode({'type': 'direct', 'id': widget.peerEmail}),
      );
    } catch (_) {}
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

  List<Widget> _buildTimeline() {
    final items = <Widget>[];
    DateTime? lastDay;
    final two = (int n) => n.toString().padLeft(2, '0');

    void addDivider(DateTime d) {
      final day = DateTime(d.year, d.month, d.day);
      if (lastDay == null || day != lastDay) {
        items.add(DayDivider(label: DayDivider.labelForDate(d)));
        lastDay = day;
      }
    }

    for (final m in _messages) {
      final created = DateTime.tryParse(m['createdAt']?.toString() ?? '');
      if (created != null) addDivider(created);
      final username = m['username']?.toString() ?? '';
      final isMe = username == widget.myEmail;
      final replyTo = m['replyTo'];
      items.add(ChatBubble(
        username: username,
        displayName: m['name']?.toString(),
        photoUrl: m['photoUrl']?.toString(),
        message: m['message']?.toString() ?? '',
        isMe: isMe,
        time: created != null ? '${two(created.hour)}:${two(created.minute)}' : null,
        status: isMe ? MessageStatus.fromServer(m['status']?.toString()) : null,
        replyTo: replyTo is Map
            ? {
                'name': replyTo['name']?.toString() ?? '',
                'message': replyTo['message']?.toString() ?? '',
              }
            : null,
        onReply: () => _startReply(m),
      ));
    }

    for (final p in _pending) {
      addDivider(p.createdAt);
      items.add(ChatBubble(
        username: widget.myEmail,
        message: p.text,
        isMe: true,
        time: '${two(p.createdAt.hour)}:${two(p.createdAt.minute)}',
        status: p.status,
        onRetry: p.status == MessageStatus.failed ? () => _retryPending(p) : null,
        replyTo: p.replyTo != null
            ? {
                'name': p.replyTo!['name']?.toString() ?? '',
                'message': p.replyTo!['message']?.toString() ?? '',
              }
            : null,
      ));
    }

    return items;
  }

  void _startReply(Map<String, dynamic> m) {
    final rawName = m['name']?.toString().trim();
    setState(() {
      _replyingTo = {
        'id': m['id'],
        'name': (rawName != null && rawName.isNotEmpty)
            ? rawName
            : (m['username']?.toString() ?? ''),
        'message': m['message']?.toString() ?? '',
      };
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();

    final replyTo = _replyingTo;
    final pending = _PendingMessage(
      localId: '${DateTime.now().microsecondsSinceEpoch}',
      text: text,
      createdAt: DateTime.now(),
      replyTo: replyTo,
    );
    setState(() {
      _pending.add(pending);
      _replyingTo = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    await _attemptSend(pending);
  }

  void _retryPending(_PendingMessage p) {
    setState(() => p.status = MessageStatus.retrying);
    _attemptSend(p);
  }

  Future<void> _attemptSend(_PendingMessage pending) async {
    try {
      final token = await secureStorage.readSecureData(key);
      final response = await http.post(
        Uri.parse(_sendApiUrl),
        headers: {'Authorization': token ?? ''},
        body: {
          'to': widget.peerEmail,
          'message': pending.text,
          if (pending.replyTo != null)
            'replyTo': pending.replyTo!['id'].toString(),
        },
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        setState(() => pending.status = MessageStatus.sent);
        // El fetch actualiza _messages y dentro de él se limpia el pending
        // si el servidor ya lo devolvió. Si aún no, el próximo poll lo hace.
        await _fetchMessages();
        if (mounted) {
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _scrollToBottom());
        }
      } else {
        setState(() => pending.status = MessageStatus.failed);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo enviar el mensaje')),
          );
        }
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => pending.status = MessageStatus.failed);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error de red al enviar el mensaje')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final peer = widget.peerEmail;
    final title = (widget.peerName?.isNotEmpty == true)
        ? widget.peerName!
        : (peer.contains('@') ? peer.substring(0, peer.indexOf('@')) : peer);
    final hasContent = _messages.isNotEmpty || _pending.isNotEmpty;

    return AppScaffold(
      padding: EdgeInsets.zero,
      safeArea: false,
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            IdentityAvatar(id: title, radius: 16),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child:
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SafeArea(
              bottom: false,
              child: _loading
                  ? const LoadingState()
                  : !hasContent
                      ? const EmptyState(
                          icon: Icons.forum_outlined,
                          title: 'Todavía no hay mensajes',
                          message: 'Sé el primero en escribir algo.',
                        )
                      : ListView(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.md),
                          children: _buildTimeline(),
                        ),
            ),
          ),
          MessageComposer(
            controller: _controller,
            onSend: _sendMessage,
            replyingTo: _replyingTo == null
                ? null
                : {
                    'name': _replyingTo!['name']?.toString() ?? '',
                    'message': _replyingTo!['message']?.toString() ?? '',
                  },
            onCancelReply: () => setState(() => _replyingTo = null),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
