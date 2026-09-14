import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/core/api_config.dart';
import 'package:doliv_social/shared/auth/login.dart';
import 'package:doliv_social/shared/chat/chat.dart';
import 'package:doliv_social/shared/chat/group_chat.dart';
import 'package:doliv_social/shared/teams/user_picker_sheet.dart';

/// Bandeja de conversaciones: una fila por persona con la que hay un hilo
/// 1 a 1, más una fila por cada chat grupal al que se pertenece (empresa y,
/// si aplica, el propio departamento). Al tocar una fila se abre
/// [ChatScreen] (1 a 1) o [GroupChatScreen] (grupo) según `type`.
///
/// Datos de `GET /chat/conversations` (hive-backend), que solo devuelve los
/// hilos y grupos en los que participa quien pregunta.
class ChatScreenfetch extends StatefulWidget {
  const ChatScreenfetch({super.key});

  @override
  State<ChatScreenfetch> createState() => _ChatScreenfetchState();
}

class _ChatScreenfetchState extends State<ChatScreenfetch> {
  List<Map<String, dynamic>> _conversations = [];
  bool _loading = true;
  bool _hasError = false;

  /// Evita que un doble toque (o un toque mientras la transición aún corre)
  /// apile dos veces la misma conversación en la pila de navegación.
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _hasError = false;
    });
    try {
      final token = await secureStorage.readSecureData(key);
      final response = await http.get(
        Uri.parse('$kBaseUrl/chat/conversations'),
        headers: <String, String>{'Authorization': token ?? ''},
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body) as Map<String, dynamic>;
        setState(() {
          _conversations = List<Map<String, dynamic>>.from(
              decoded['conversations'] ?? const []);
          _loading = false;
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

  Future<void> _openThread(Map<String, dynamic> convo) async {
    if (_opening) return;
    _opening = true;
    final bool isGroup = convo['type'] == 'group';
    try {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => isGroup
              ? GroupChatScreen(groupId: convo['groupId']?.toString() ?? '')
              : ChatScreen(
                  peerEmail: convo['peerEmail']?.toString() ?? '',
                  peerName: convo['peerName']?.toString(),
                ),
        ),
      );
    } finally {
      _opening = false;
    }
    if (mounted) _fetch(); // refresca no leídos al volver
  }

  Future<void> _startNewChat() async {
    final person = await pickPerson(context, title: 'Iniciar chat con...');
    if (person == null || !mounted) return;
    await _openThread({'peerEmail': person.email, 'peerName': person.name});
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      padding: EdgeInsets.zero,
      appBar: AppBar(
        title: const Text('Mensajes'),
        automaticallyImplyLeading: false,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const LoadingState();
    if (_hasError) return ErrorState(onRetry: _fetch);
    if (_conversations.isEmpty) {
      return EmptyState(
        icon: Icons.forum_outlined,
        title: 'Todavía no tienes conversaciones',
        message: 'Abre el perfil de un compañero y toca "Enviar mensaje",\n'
            'o inicia un chat directamente.',
        action: OutlinedButton.icon(
          onPressed: _startNewChat,
          icon: const Icon(Icons.add_comment_outlined, size: 18),
          label: const Text('Iniciar chat'),
        ),
      );
    }
    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: _fetch,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        itemCount: _conversations.length,
        separatorBuilder: (_, __) =>
            Divider(height: 1, color: AppColors.surfaceBorder),
        itemBuilder: (context, index) {
          final c = _conversations[index];
          final bool isGroup = c['type'] == 'group';
          final int unread = (c['unread'] as num?)?.toInt() ?? 0;
          final bool fromMe = c['lastFromMe'] == true;
          final String name = c['peerName']?.toString() ?? '';
          final String? lastMessage = c['lastMessage']?.toString();
          final String preview = lastMessage == null
              ? 'Todavía no hay mensajes'
              : '${fromMe ? 'Tú: ' : ''}$lastMessage';
          return ListTile(
            leading: isGroup
                ? CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.accent.withValues(alpha: 0.15),
                    child: Icon(Icons.groups_rounded,
                        color: AppColors.accent, size: 22),
                  )
                : IdentityAvatar(
                    id: c['peerEmail']?.toString() ?? name,
                    radius: 20,
                  ),
            title: Text(
              name,
              style: TextStyle(
                fontWeight: unread > 0 ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
            subtitle: Text(
              preview,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: unread > 0 ? AppColors.textPrimary : AppColors.textMuted,
              ),
            ),
            trailing: unread > 0 ? UnreadCountBadge(count: unread) : null,
            onTap: () => _openThread(c),
          );
        },
      ),
    );
  }
}
