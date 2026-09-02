import 'dart:async';
import 'dart:convert';
import 'package:brl_task4/screens/chatHistory.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../design/design.dart';
import '../models/message_status.dart';
import '../utils/api_config.dart';
import 'login.dart';

/// Mensaje propio que todavía no se confirmó contra el servidor (o que
/// falló al enviarse). Vive aparte de [_messages] —que siempre refleja lo
/// último que devolvió el backend— para poder mostrarlo de inmediato
/// (estilo WhatsApp: el mensaje aparece al toque de enviar, con un reloj,
/// y va cambiando de estado) sin esperar al siguiente sondeo.
class _PendingMessage {
  _PendingMessage({required this.localId, required this.text, required this.createdAt});

  final String localId;
  final String text;
  final DateTime createdAt;
  MessageStatus status = MessageStatus.sending;
}

/// Chat de un equipo específico: solo lo ven y pueden escribir en él los
/// integrantes de ese equipo (el backend lo valida en cada llamada).
class ChatScreen extends StatefulWidget {
  final String teamId;
  final String myEmail;
  final String? teamName;

  const ChatScreen({super.key, required this.teamId, required this.myEmail, this.teamName});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  final List<_PendingMessage> _pending = [];
  final ScrollController _scrollController = ScrollController();
  late String myUsername;
  Timer? _pollTimer;
  bool _loading = true;

  String get _chatApiUrl => '$kBaseUrl/chat/getAllChats/${widget.teamId}';
  String get _sendApiUrl => '$kBaseUrl/chat/sendMessage/${widget.teamId}';

  @override
  void initState() {
    super.initState();
    myUsername = widget.myEmail;
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
                  'name': c['name'],
                  'photoUrl': c['photoUrl'],
                  'createdAt': c['createdAt'],
                  'status': c['status'],
                }));
          _loading = false;
        });
        if (wasAtBottom) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
        }
        // Con este chat abierto, todo lo que haya (incluido lo que se acaba
        // de traer) cuenta como leído: así el badge de "Mensajes" no sigue
        // sumando mientras la persona está viendo la conversación.
        _markRead();
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // No bloquea el chat si falla: es solo para el badge de no leídos en el
  // dashboard de "Mensajes", no afecta la lectura/envío de mensajes.
  Future<void> _markRead() async {
    try {
      final token = await secureStorage.readSecureData(key);
      await http.post(
        Uri.parse('$kBaseUrl/chat/read'),
        headers: <String, String>{
          'Authorization': token ?? '',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'type': 'team', 'id': widget.teamId}),
      );
    } catch (_) {
      // Silencioso a propósito.
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

  /// Arma la lista que se dibuja en pantalla intercalando un [DayDivider]
  /// cada vez que cambia el día entre un mensaje y el siguiente — igual que
  /// WhatsApp ("HOY", "AYER", etc. — ver [DayDivider.labelForDate]) — y
  /// agregando al final los mensajes propios que todavía no confirma el
  /// servidor (ver [_PendingMessage]).
  List<Widget> _buildTimeline() {
    final items = <Widget>[];
    DateTime? lastDay;

    void addDayDividerIfNeeded(DateTime created) {
      final day = DateTime(created.year, created.month, created.day);
      if (lastDay == null || day != lastDay) {
        items.add(DayDivider(label: DayDivider.labelForDate(created)));
        lastDay = day;
      }
    }

    for (final m in _messages) {
      final created = DateTime.tryParse(m['createdAt']?.toString() ?? '');
      if (created != null) addDayDividerIfNeeded(created);
      final message = m['message']?.toString() ?? '';
      final username = m['username']?.toString() ?? '';
      final displayName = m['name']?.toString();
      final photoUrl = m['photoUrl']?.toString();
      final two = (int n) => n.toString().padLeft(2, '0');
      final time = created != null ? '${two(created.hour)}:${two(created.minute)}' : null;
      final isMe = username == myUsername;
      items.add(ChatBubble(
        username: username,
        displayName: displayName,
        photoUrl: photoUrl,
        message: message,
        isMe: isMe,
        time: time,
        status: isMe ? MessageStatus.fromServer(m['status']?.toString()) : null,
      ));
    }

    for (final p in _pending) {
      addDayDividerIfNeeded(p.createdAt);
      final two = (int n) => n.toString().padLeft(2, '0');
      items.add(ChatBubble(
        username: myUsername,
        message: p.text,
        isMe: true,
        time: '${two(p.createdAt.hour)}:${two(p.createdAt.minute)}',
        status: p.status,
        onRetry: p.status == MessageStatus.failed ? () => _retryPending(p) : null,
      ));
    }

    return items;
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();

    final pending = _PendingMessage(
      localId: '${DateTime.now().microsecondsSinceEpoch}',
      text: text,
      createdAt: DateTime.now(),
    );
    setState(() => _pending.add(pending));
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    await _attemptSend(pending);
  }

  void _retryPending(_PendingMessage pending) {
    setState(() => pending.status = MessageStatus.retrying);
    _attemptSend(pending);
  }

  Future<void> _attemptSend(_PendingMessage pending) async {
    try {
      final token = await secureStorage.readSecureData(key);
      final response = await http.post(
        Uri.parse(_sendApiUrl),
        headers: <String, String>{'Authorization': token ?? ''},
        body: {'message': pending.text},
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        setState(() => pending.status = MessageStatus.sent);
        // Se refresca la conversación para traer la copia oficial del
        // servidor (con su estado real: entregado/leído) y recién ahí se
        // quita el mensaje "pendiente", para que no desaparezca de golpe.
        await _fetchMessages();
        if (!mounted) return;
        setState(() => _pending.removeWhere((p) => p.localId == pending.localId));
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
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
    final hasContent = _messages.isNotEmpty || _pending.isNotEmpty;
    return AppScaffold(
      padding: EdgeInsets.zero,
      safeArea: false,
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.surface,
              child: Icon(Icons.groups, color: AppColors.accent, size: 18),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                widget.teamName == null || widget.teamName!.isEmpty ? 'Chat' : widget.teamName!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Historial',
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatScreenfetch(
                    teamId: widget.teamId,
                    teamName: widget.teamName,
                  ),
                ),
              );
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
                  : !hasContent
                      ? const EmptyState(
                          icon: Icons.forum_outlined,
                          title: 'Todavía no hay mensajes',
                          message: 'Sé el primero en escribir algo.',
                        )
                      : ListView(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                          children: _buildTimeline(),
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
