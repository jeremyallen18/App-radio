import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../design/design.dart';
import '../utils/api_config.dart';
import '../utils/session.dart';
import 'chat.dart';
import 'directChat.dart';
import 'login.dart';

/// Filtro de la lista de chats: todos, solo equipo o solo no leídos (de
/// equipo y directos por igual).
enum _ChatFilter { all, team, unread }

/// Dashboard de "Mensajes": una sola lista, tipo WhatsApp, con los chats de
/// equipo (grupo) y los chats directos (1 a 1) a los que pertenece el
/// usuario, cada uno con una vista previa del último mensaje. Al tocar una
/// fila se abre [ChatScreen] (si es de equipo) o [DirectChatScreen] (si es
/// directo) — el envío y la recepción de mensajes ya los maneja cada una de
/// esas pantallas, aquí solo se decide a cuál entrar.
class MessagesDashboardScreen extends StatefulWidget {
  const MessagesDashboardScreen({super.key});

  @override
  State<MessagesDashboardScreen> createState() => _MessagesDashboardScreenState();
}

class _MessagesDashboardScreenState extends State<MessagesDashboardScreen> {
  List<Map<String, dynamic>> _chats = [];
  String? _myEmail;
  bool _loading = true;
  bool _hasError = false;

  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  _ChatFilter _filter = _ChatFilter.all;

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _hasError = false;
    });
    try {
      final token = await secureStorage.readSecureData(key);
      final myEmail = await Session.resolveEmail(token);
      final response = await http.get(
        Uri.parse('$kBaseUrl/chat/list'),
        headers: <String, String>{'Authorization': token ?? ''},
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final List<dynamic> chats = decoded['chats'] ?? [];
        setState(() {
          _myEmail = myEmail;
          _chats = chats.map((c) => Map<String, dynamic>.from(c as Map)).toList();
          _loading = false;
        });
      } else {
        setState(() {
          _hasError = true;
          _loading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _loading = false;
      });
    }
  }

  void _openChat(Map<String, dynamic> chat) {
    final myEmail = _myEmail ?? '';
    final bool isGroup = chat['type'] == 'team';
    final String id = chat['id']?.toString() ?? '';
    final String title = chat['title']?.toString() ?? '';

    if (isGroup) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(teamId: id, myEmail: myEmail, teamName: title),
        ),
      ).then((_) => _load());
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DirectChatScreen(peerEmail: id, myEmail: myEmail, peerName: title),
        ),
      ).then((_) => _load());
    }
  }

  /// "21:57" si el mensaje es de hoy; "15/08" si es de otro día. Sin
  /// mensajes todavía, se devuelve null y no se muestra ninguna hora.
  String? _formatTimestamp(String? raw) {
    if (raw == null) return null;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return null;
    final now = DateTime.now();
    final two = (int n) => n.toString().padLeft(2, '0');
    if (parsed.year == now.year && parsed.month == now.month && parsed.day == now.day) {
      return '${two(parsed.hour)}:${two(parsed.minute)}';
    }
    return '${two(parsed.day)}/${two(parsed.month)}';
  }

  int _unreadCountOf(Map<String, dynamic> chat) {
    final raw = chat['unreadCount'];
    return raw is num ? raw.toInt() : int.tryParse(raw?.toString() ?? '') ?? 0;
  }

  List<Map<String, dynamic>> get _visibleChats {
    return _chats.where((chat) {
      final bool isGroup = chat['type'] == 'team';
      if (_filter == _ChatFilter.team && !isGroup) return false;
      if (_filter == _ChatFilter.unread && _unreadCountOf(chat) <= 0) return false;
      if (_query.isEmpty) return true;
      final title = (chat['title']?.toString() ?? '').toLowerCase();
      final last = (chat['lastMessage']?.toString() ?? '').toLowerCase();
      return title.contains(_query) || last.contains(_query);
    }).toList();
  }

  int get _totalUnread => _chats.fold<int>(0, (sum, c) => sum + _unreadCountOf(c));

  @override
  Widget build(BuildContext context) {
    final visible = _visibleChats;

    return AppScaffold(
      padding: EdgeInsets.zero,
      safeArea: false,
      backgroundColor: AppColors.bgBase,
      appBar: AppBar(
        title: const Text('Mensajes'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _MessagesHeader(
              searchController: _searchController,
              totalUnread: _totalUnread,
              filter: _filter,
              onFilterChanged: (f) => setState(() => _filter = f),
            ),
            Expanded(
              child: _loading
                  ? const LoadingState()
                  : _hasError
                      ? ErrorState(onRetry: _load)
                      : _chats.isEmpty
                          ? const EmptyState(
                              icon: Icons.chat_bubble_outline,
                              title: 'Todavía no tienes chats',
                              message:
                                  'Los chats de tus equipos y tus conversaciones directas van a aparecer aquí.',
                            )
                          : visible.isEmpty
                              ? EmptyState(
                                  icon: Icons.search_off,
                                  title: 'Sin resultados',
                                  message: 'No encontramos chats que coincidan con tu búsqueda.',
                                )
                              : RefreshIndicator(
                                  onRefresh: _load,
                                  color: AppColors.accent,
                                  backgroundColor: AppColors.surface,
                                  child: ListView.builder(
                                    padding: const EdgeInsets.fromLTRB(
                                      AppSpacing.lg,
                                      AppSpacing.sm,
                                      AppSpacing.lg,
                                      AppSpacing.xl,
                                    ),
                                    itemCount: visible.length,
                                    itemBuilder: (context, index) {
                                      final chat = visible[index];
                                      final bool isGroup = chat['type'] == 'team';
                                      final String title = chat['title']?.toString() ?? '';
                                      final String? lastMessage = chat['lastMessage']?.toString();
                                      final String? photoUrl = chat['photoUrl']?.toString();
                                      final String? time =
                                          _formatTimestamp(chat['lastMessageAt']?.toString());
                                      final int unreadCount = _unreadCountOf(chat);
                                      final bool unread = unreadCount > 0;

                                      return _ChatRow(
                                        isGroup: isGroup,
                                        title: title,
                                        lastMessage: lastMessage,
                                        photoUrl: photoUrl,
                                        time: time,
                                        unreadCount: unreadCount,
                                        unread: unread,
                                        onTap: () => _openChat(chat),
                                      );
                                    },
                                  ),
                                ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Barra de búsqueda + chips de filtro (Todos / Equipos / No leídos) que
/// encabeza la lista de chats. El chip "No leídos" filtra a solo los chats
/// (de equipo o directos) con mensajes sin leer, y muestra el total de
/// mensajes sin leer como una burbuja con solo el número.
class _MessagesHeader extends StatelessWidget {
  const _MessagesHeader({
    required this.searchController,
    required this.totalUnread,
    required this.filter,
    required this.onFilterChanged,
  });

  final TextEditingController searchController;
  final int totalUnread;
  final _ChatFilter filter;
  final ValueChanged<_ChatFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.md),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.surfaceBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(color: AppColors.surfaceBorder),
            ),
            child: TextField(
              controller: searchController,
              style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
              cursorColor: AppColors.textPrimary,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                hintText: 'Buscar chats o mensajes…',
                hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 14),
                prefixIcon: Icon(Icons.search, color: AppColors.textMuted, size: 20),
                suffixIcon: searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: Icon(Icons.close, color: AppColors.textMuted, size: 18),
                        onPressed: searchController.clear,
                      ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _FilterChip(
                label: 'Todos',
                selected: filter == _ChatFilter.all,
                onTap: () => onFilterChanged(_ChatFilter.all),
              ),
              const SizedBox(width: AppSpacing.sm),
              _FilterChip(
                icon: Icons.groups,
                label: 'Equipos',
                selected: filter == _ChatFilter.team,
                onTap: () => onFilterChanged(_ChatFilter.team),
              ),
              const SizedBox(width: AppSpacing.sm),
              _FilterChip(
                icon: Icons.mark_chat_unread_outlined,
                label: 'No leídos',
                selected: filter == _ChatFilter.unread,
                onTap: () => onFilterChanged(_ChatFilter.unread),
                count: totalUnread,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.count,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  /// Si viene y es mayor a 0, se muestra como una burbuja con SOLO el
  /// número (sin ningún texto extra) al final del chip — p. ej. el total
  /// de mensajes sin leer en el chip "No leídos".
  final int? count;

  @override
  Widget build(BuildContext context) {
    final bool showCount = count != null && count! > 0;
    return Material(
      color: selected ? AppColors.brandBlue : AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: selected ? Colors.transparent : AppColors.surfaceBorder,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Fondo del chip seleccionado siempre azul (brandBlue, fijo):
              // el color de encima debe quedar fijo en blanco en vez de
              // AppColors.textPrimary (se oscurece en modo claro y se
              // pierde contra el azul).
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 14,
                  color: selected ? AppColors.onBrand : AppColors.textMuted,
                ),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  color: selected ? AppColors.onBrand : AppColors.textMuted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (showCount) ...[
                const SizedBox(width: 6),
                UnreadCountBadge(count: count!, size: 16),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Fila de un chat en la lista: tarjeta con borde suave, franja de acento a
/// la izquierda cuando hay mensajes sin leer, avatar (con distintivo de
/// equipo/directo) y una vista previa del último mensaje.
class _ChatRow extends StatelessWidget {
  const _ChatRow({
    required this.isGroup,
    required this.title,
    required this.lastMessage,
    required this.photoUrl,
    required this.time,
    required this.unreadCount,
    required this.unread,
    required this.onTap,
  });

  final bool isGroup;
  final String title;
  final String? lastMessage;
  final String? photoUrl;
  final String? time;
  final int unreadCount;
  final bool unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: unread ? AppColors.surface : AppColors.bgBase,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(
                color: unread ? AppColors.accent.withValues(alpha: 0.35) : AppColors.surfaceBorder,
              ),
            ),
            child: Row(
              children: [
                // Franja de acento: solo visible cuando hay mensajes sin leer.
                Container(
                  width: 4,
                  height: 64,
                  decoration: BoxDecoration(
                    color: unread ? AppColors.accent : Colors.transparent,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(AppRadius.card),
                      bottomLeft: Radius.circular(AppRadius.card),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      isGroup
                          ? CircleAvatar(
                              radius: 24,
                              backgroundColor: AppColors.surface,
                              child: Icon(Icons.groups, color: AppColors.accent),
                            )
                          : IdentityAvatar(id: title, radius: 24, photoUrl: photoUrl),
                      if (isGroup)
                        Positioned(
                          bottom: -2,
                          right: -2,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: AppColors.bgBase,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.surfaceBorder),
                            ),
                            child: Icon(Icons.tag, size: 10, color: AppColors.textMuted),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          lastMessage ?? 'Todavía no hay mensajes',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: unread ? AppColors.textPrimary : AppColors.textMuted,
                            fontSize: 13,
                            fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.md, left: AppSpacing.xs),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (time != null)
                        Text(
                          time!,
                          style: TextStyle(
                            color: unread ? AppColors.accentStrong : AppColors.textMuted,
                            fontSize: 12,
                            fontWeight: unread ? FontWeight.w700 : FontWeight.w400,
                          ),
                        ),
                      const SizedBox(height: 6),
                      // Burbuja de "sin leer" tipo WhatsApp: solo aparece
                      // si hay mensajes de la otra persona/equipo que
                      // todavía no marqué como leídos (unreadCountAPI en
                      // hive-backend/index.php, listChats()).
                      UnreadCountBadge(count: unreadCount),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
