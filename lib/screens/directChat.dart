import 'dart:async';
import 'dart:convert';
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

/// Chat privado 1 a 1: a diferencia de [ChatScreen] (por equipo, en
/// chat.dart), este hilo solo lo ven quien lo envía y `peerEmail`. Se abre,
/// por ejemplo, al tocar el correo de un integrante de un área en
/// teamDetail.dart. El backend (getDirectChat/sendDirectMessage en
/// hive-backend/index.php) filtra los mensajes por ese par de correos en
/// ambos sentidos, así que nadie más puede leerlo ni escribir en él.
class DirectChatScreen extends StatefulWidget {
  final String peerEmail;
  final String myEmail;
  /// Nombre a mostrar en el AppBar; si no llega, se usa la parte del
  /// correo antes de la @.
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
  late String myUsername;
  Timer? _pollTimer;
  bool _loading = true;

  String get _chatApiUrl =>
      '$kBaseUrl/chat/direct?with=${Uri.encodeQueryComponent(widget.peerEmail)}';
  String get _sendApiUrl => '$kBaseUrl/chat/direct';

  @override
  void initState() {
    super.initState();
    myUsername = widget.myEmail;
    _fetchMessages();
    // Mismo intervalo que el chat de equipo (chat.dart), para que los
    // mensajes nuevos aparezcan sin tener que salir y volver a entrar.
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
        body: jsonEncode({'type': 'direct', 'id': widget.peerEmail}),
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
        body: {'to': widget.peerEmail, 'message': pending.text},
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
    final String rawPeer = widget.peerEmail;
    final String title = (widget.peerName != null && widget.peerName!.isNotEmpty)
        ? widget.peerName!
        : (rawPeer.contains('@') ? rawPeer.substring(0, rawPeer.indexOf('@')) : rawPeer);
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
              child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
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
