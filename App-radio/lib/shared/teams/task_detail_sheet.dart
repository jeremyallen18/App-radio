import 'package:flutter/material.dart';

import 'package:doliv_social/core/session.dart';
import 'package:doliv_social/core/session_keys.dart' show secureStorage, key;
import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/models/dept_task.dart';
import 'package:doliv_social/services/team_service.dart';

/// Ficha de una tarea con su hilo de comentarios (aclaraciones entre el
/// manager y el empleado asignado, sin salir a un chat aparte).
///
/// [canComment] lo decide quien abre la pantalla: director/manager del
/// departamento o el empleado asignado.
class TaskDetailSheet extends StatefulWidget {
  const TaskDetailSheet({
    super.key,
    required this.task,
    required this.canComment,
  });

  final DeptTask task;
  final bool canComment;

  @override
  State<TaskDetailSheet> createState() => _TaskDetailSheetState();
}

class _TaskDetailSheetState extends State<TaskDetailSheet> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  List<TaskComment> _comments = const [];
  String? _myId;
  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await secureStorage.readSecureData(key);
      final comments = await DeptTaskApi.comments(widget.task.id);
      final me = await Session.fetchCurrentUser((token as String?) ?? '');
      if (!mounted) return;
      setState(() {
        _comments = comments;
        _myId = me?.id;
        _loading = false;
      });
      _jumpToEnd();
    } on TeamException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  void _jumpToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final added = await DeptTaskApi.addComment(widget.task.id, text);
      if (!mounted) return;
      setState(() {
        _comments = [..._comments, added];
        _controller.clear();
        _sending = false;
      });
      _jumpToEnd();
    } on TeamException catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.task;
    return AppScaffold(
      appBar: AppBar(leading: const AppBackButton(), title: const Text('Detalle de la tarea')),
      padding: EdgeInsets.zero,
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const LoadingState()
                : _error != null
                    ? ErrorState(message: _error!, onRetry: _load)
                    : ListView(
                        controller: _scroll,
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        children: [
                          _header(t),
                          const SizedBox(height: AppSpacing.lg),
                          const SectionHeader(title: 'Comentarios'),
                          const SizedBox(height: AppSpacing.sm),
                          if (_comments.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                              child: Text(
                                'Todavía no hay comentarios.',
                                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                              ),
                            )
                          else
                            for (final c in _comments)
                              Padding(
                                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                                child: ChatBubble(
                                  username: c.author?.name ?? 'Alguien',
                                  message: c.body,
                                  isMe: _myId != null && c.author?.id == _myId,
                                ),
                              ),
                        ],
                      ),
          ),
          if (widget.canComment && !_loading && _error == null)
            MessageComposer(
              controller: _controller,
              onSend: _send,
              hintText: 'Escribe un comentario…',
            ),
        ],
      ),
    );
  }

  Widget _header(DeptTask t) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.title,
              style: const TextStyle(
                  color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 16)),
          if ((t.description ?? '').isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(t.description!,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
          ],
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: 4,
            children: [
              _tag(t.statusLabel),
              if (t.completedLate) _tag('Retardo', icon: Icons.timer_off_outlined),
              _tag('Revisión: ${t.reviewStatusLabel}'),
              if (t.assignedTo != null)
                _tag(t.assignedTo!.name, icon: Icons.person_outline),
              if (t.dueLabel != null) _tag(t.dueLabel!, icon: Icons.event_outlined),
              if (t.isRecurring) _tag(t.recurrence.label, icon: Icons.repeat),
              if (t.requiresEvidence)
                _tag('Requiere evidencia', icon: Icons.attach_file),
            ],
          ),
          if (t.wasRejected && (t.reviewNote ?? '').isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text('Devuelta: ${t.reviewNote}',
                style: const TextStyle(color: AppColors.error, fontSize: 12)),
          ],
        ],
      ),
    );
  }

  Widget _tag(String text, {IconData? icon}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: AppColors.textMuted),
              const SizedBox(width: 3),
            ],
            Text(text,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ],
        ),
      );
}
