import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/core/api_config.dart';
import 'package:doliv_social/shared/auth/login.dart';

/// Conversación privada 1 a 1 con un compañero.
///
/// El hilo se identifica por el correo de la otra persona ([peerEmail]); el
/// backend (`GET /chat/thread/{correo}`, `POST /chat/sendMessage {to,message}`)
/// solo devuelve mensajes en los que participa quien pregunta, así que nadie
/// puede leer una conversación ajena cambiando el destinatario.
class ChatScreen extends StatefulWidget {
  final String peerEmail;
  final String? peerName;

  const ChatScreen({super.key, required this.peerEmail, this.peerName});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  final ScrollController _scrollController = ScrollController();
  Timer? _pollTimer;
  bool _loading = true;
  bool _sending = false;
  bool _emojiOpen = false;
  String _peerName = '';

  String get _threadUrl =>
      '$kBaseUrl/chat/thread/${Uri.encodeComponent(widget.peerEmail)}';
  static const String _sendApiUrl = '$kBaseUrl/chat/sendMessage';

  @override
  void initState() {
    super.initState();
    _peerName = widget.peerName ?? _shortEmail(widget.peerEmail);
    _fetchMessages();
    // Sondeo cada 5 s (antes 3 s, demasiado agresivo) y solo mientras este
    // hilo es la pantalla visible: si hay otra pantalla encima, no se
    // consulta hasta volver.
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      final isCurrent = ModalRoute.of(context)?.isCurrent ?? true;
      if (isCurrent) _fetchMessages();
    });
  }

  String _shortEmail(String email) =>
      email.contains('@') ? email.substring(0, email.indexOf('@')) : email;

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
        final peer = decoded['peer'] as Map<String, dynamic>?;
        final bool wasAtBottom = _isNearBottom();
        setState(() {
          if (peer != null && (peer['name']?.toString().isNotEmpty ?? false)) {
            _peerName = peer['name'].toString();
          }
          _messages
            ..clear()
            ..addAll(msgs.map((m) => {
                  'message': m['message'],
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
        Uri.parse(_sendApiUrl),
        headers: <String, String>{'Authorization': token ?? ''},
        body: {'to': widget.peerEmail, 'message': text},
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

  /// Filas del chat: cada mensaje, precedido de un [DayDivider] cuando
  /// cambia el día respecto al mensaje anterior.
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
        username: fromMe ? 'Tú' : _peerName,
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
        title: Text(_peerName),
        leading: AppBackButton.leadingFor(context),
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
                          icon: Icons.forum_outlined,
                          title: 'Todavía no hay mensajes',
                          message: 'Escríbele a $_peerName para empezar.',
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
            onSend: _sendMessage,
            emojiActive: _emojiOpen,
            onToggleEmoji: () => setState(() => _emojiOpen = !_emojiOpen),
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
    super.dispose();
  }
}
