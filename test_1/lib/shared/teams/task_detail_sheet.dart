import 'package:flutter/material.dart';

import 'package:doliv_social/core/session.dart';
import 'package:doliv_social/core/session_keys.dart' show secureStorage, key;
import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/models/dept_task.dart';
import 'package:doliv_social/services/team_service.dart';
import 'package:doliv_social/shared/teams/widgets/task_visuals.dart';
import 'package:doliv_social/shared/widgets/evidence_viewer.dart';

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

  void _openEvidence() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EvidenceViewer(
          url: DeptTaskApi.evidenceUrl(widget.task.id),
          title: 'Evidencia · ${widget.task.title}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.task;
    return AppScaffold(
      appBar: AppBar(
        leading: AppBackButton.leadingFor(context),
        automaticallyImplyLeading: false,
        title: Text(t.isSubtask ? 'Subtarea' : 'Tarea'),
      ),
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
                          _TaskHeader(task: t),
                          const SizedBox(height: AppSpacing.md),
                          _FactsGrid(task: t, onOpenEvidence: t.hasEvidence ? _openEvidence : null),
                          if (t.wasRejected && (t.reviewNote ?? '').isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.md),
                            _ReturnedNote(note: t.reviewNote!, by: t.reviewedBy?.name),
                          ],
                          const SizedBox(height: AppSpacing.xl),
                          SectionHeader(
                            title: 'Comentarios',
                            action: _comments.isEmpty
                                ? null
                                : Text('${_comments.length}', style: const TextStyle(color: AppColors.textMuted)),
                          ),
                          if (_comments.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                              child: Text(
                                widget.canComment
                                    ? 'Aún no hay comentarios. Escribe el primero abajo.'
                                    : 'Todavía no hay comentarios.',
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                              ),
                            )
                          else
                            for (final c in _comments)
                              Padding(
                                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                                child: _CommentBubble(
                                  username: c.author?.name ?? 'Alguien',
                                  message: c.body,
                                  isMe: _myId != null && c.author?.id == _myId,
                                ),
                              ),
                        ],
                      ),
          ),
          if (widget.canComment && !_loading && _error == null)
            _CommentComposer(
              controller: _controller,
              onSend: _send,
            ),
        ],
      ),
    );
  }
}

/// Cabecera: riel de tono, chip de estado, título grande, descripción,
/// cuenta atrás y barra de subtareas.
class _TaskHeader extends StatelessWidget {
  const _TaskHeader({required this.task});
  final DeptTask task;

  @override
  Widget build(BuildContext context) {
    final tone = TaskTone.of(task);
    return GlassPanel(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              StatusRail(color: tone.color),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        StatusChip(tone: tone),
                        const Spacer(),
                        TaskFlags(task: task),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      task.title,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                        height: 1.2,
                        decoration: task.isDone ? TextDecoration.lineThrough : null,
                        decorationColor: AppColors.textMuted,
                      ),
                    ),
                    if ((task.description ?? '').isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(task.description!, style: const TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.4)),
                    ],
                    if (task.subtaskCount > 0) ...[
                      const SizedBox(height: AppSpacing.md),
                      SubtaskProgress(done: task.subtaskDoneCount, total: task.subtaskCount),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rejilla de datos de la tarea, dos por fila.
class _FactsGrid extends StatelessWidget {
  const _FactsGrid({required this.task, this.onOpenEvidence});
  final DeptTask task;
  final VoidCallback? onOpenEvidence;

  @override
  Widget build(BuildContext context) {
    final t = task;
    final facts = <Widget>[
      _Fact(
        icon: Icons.person_outline_rounded,
        label: 'Responsable',
        value: t.assignedTo?.name ?? 'Sin asignar',
        muted: t.assignedTo == null,
      ),
      _Fact(
        icon: Icons.schedule_rounded,
        label: 'Fecha límite',
        value: t.dueDate == null ? 'Sin fecha' : t.dueLabel!,
        muted: t.dueDate == null,
        trailing: t.dueDate == null ? null : DueChip(task: t),
      ),
      _Fact(
        icon: Icons.fact_check_outlined,
        label: 'Revisión',
        value: t.reviewStatusLabel,
        valueColor: switch (t.reviewStatus) {
          DeptTaskReviewStatus.aprobada => AppColors.success,
          DeptTaskReviewStatus.rechazada => AppColors.error,
          DeptTaskReviewStatus.pendienteRevision => AppColors.warning,
          DeptTaskReviewStatus.sinRevision => null,
        },
      ),
      if (t.isRecurring)
        _Fact(icon: Icons.repeat_rounded, label: 'Repetición', value: t.recurrence.label),
      if (t.requiresEvidence || t.hasEvidence)
        _Fact(
          icon: t.hasEvidence ? Icons.photo_outlined : Icons.attach_file_rounded,
          label: 'Evidencia',
          value: t.hasEvidence ? 'Ver foto' : 'Requerida al completar',
          valueColor: t.hasEvidence ? AppColors.accentStrong : null,
          muted: !t.hasEvidence,
          onTap: onOpenEvidence,
        ),
      if (t.completedBy != null)
        _Fact(
          icon: Icons.task_alt_rounded,
          label: t.completedLate ? 'Completada con retardo' : 'Completada por',
          value: t.completedBy!.name,
          valueColor: t.completedLate ? AppColors.error : null,
        ),
      if (t.createdBy != null)
        _Fact(icon: Icons.edit_calendar_outlined, label: 'Creada por', value: t.createdBy!.name),
    ];

    return LayoutBuilder(
      builder: (context, c) {
        final w = (c.maxWidth - AppSpacing.sm) / 2;
        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [for (final f in facts) SizedBox(width: w, child: f)],
        );
      },
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.muted = false,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final bool muted;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          trailing ??
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: valueColor ?? (muted ? AppColors.textMuted : AppColors.textPrimary),
                  fontSize: 14,
                  fontWeight: muted ? FontWeight.w500 : FontWeight.w700,
                ),
              ),
        ],
      ),
    );
  }
}

class _ReturnedNote extends StatelessWidget {
  const _ReturnedNote({required this.note, this.by});
  final String note;
  final String? by;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.undo_rounded, size: 18, color: AppColors.error),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  by == null ? 'Devuelta para corregir' : 'Devuelta por $by',
                  style: const TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(note, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Burbuja simple de un comentario de tarea (sustituye al antiguo `ChatBubble`
/// del módulo de chat, ya retirado de este clon).
class _CommentBubble extends StatelessWidget {
  const _CommentBubble({
    required this.username,
    required this.message,
    required this.isMe,
  });

  final String username;
  final String message;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isMe
              ? AppColors.accent.withValues(alpha: 0.16)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              username,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              message,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Caja de texto + botón de enviar para el hilo de comentarios (sustituye al
/// antiguo `MessageComposer` del módulo de chat).
class _CommentComposer extends StatelessWidget {
  const _CommentComposer({
    required this.controller,
    required this.onSend,
  });

  final TextEditingController controller;
  final Future<void> Function() onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.md,
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Escribe un comentario…',
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    borderSide: const BorderSide(color: AppColors.surfaceBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    borderSide: const BorderSide(color: AppColors.surfaceBorder),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            IconButton(
              onPressed: () => onSend(),
              icon: const Icon(Icons.send_rounded, color: AppColors.accent),
              tooltip: 'Enviar',
            ),
          ],
        ),
      ),
    );
  }
}
