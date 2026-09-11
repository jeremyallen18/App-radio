import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:doliv_social/core/session.dart';
import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/models/dept_task.dart';
import 'package:doliv_social/models/models.dart';
import 'package:doliv_social/models/sub_team.dart';
import 'package:doliv_social/services/sub_team_service.dart';
import 'package:doliv_social/services/team_service.dart';
import 'package:doliv_social/shared/teams/evidence_confirm_sheet.dart';
import 'package:doliv_social/shared/teams/task_board_card.dart';
import 'package:doliv_social/shared/teams/task_detail_sheet.dart';
import 'package:doliv_social/shared/teams/task_form_screen.dart';
import 'package:doliv_social/shared/teams/widgets/board_summary.dart';
import 'package:doliv_social/shared/widgets/app_menu_drawer.dart';
import 'package:doliv_social/shared/widgets/evidence_viewer.dart';

/// Tablero de tareas de un departamento/equipo, a pantalla completa.
/// Reutiliza [TaskBoardBody]; la pestaña "Tablero" usa el body directamente.
class TaskBoardScreen extends StatelessWidget {
  const TaskBoardScreen({
    super.key,
    required this.departmentId,
    required this.departmentName,
    required this.canManage,
    this.currentUserId,
    this.subTeamId,
    this.subTeamName,
  });

  final String departmentId;
  final String departmentName;
  final bool canManage;
  final String? currentUserId;

  /// Si no es null, el tablero queda fijo a ese sub-equipo (migración 030):
  /// no muestra el filtro de sub-equipos y toda tarea nueva nace en él. Lo
  /// usa la entrada "Tablero del sub-equipo" del sub-líder.
  final String? subTeamId;
  final String? subTeamName;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      drawer: const AppMenuDrawer(),
      appBar: AppBar(
        leading: const BackButton(),
        title: Text('Tareas · $departmentName'),
        actions: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              tooltip: 'Menú',
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
        ],
      ),
      body: TaskBoardBody(
        departmentId: departmentId,
        canManage: canManage,
        currentUserId: currentUserId,
        fixedSubTeamId: subTeamId,
        fixedSubTeamName: subTeamName,
      ),
    );
  }
}

/// Contenido del tablero (sin Scaffold): lista de tareas con sus subtareas,
/// filtros y — para director/manager — creación/edición/borrado.
///
/// - `canManage` (director / manager): crear tareas y subtareas, editar,
///   eliminar y cambiar el estado.
/// - empleado (`canManage == false`): solo marca como completadas las tareas
///   suyas o sin responsable. Puede filtrar "Solo mías".
/// - director: conserva todos los permisos de gestión y de revisión
///   (aprobar/devolver), pero NUNCA puede marcar una tarea como completada;
///   eso le corresponde al manager o al empleado asignado.
class TaskBoardBody extends StatefulWidget {
  const TaskBoardBody({
    super.key,
    required this.departmentId,
    required this.canManage,
    this.currentUserId,
    this.fixedSubTeamId,
    this.fixedSubTeamName,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.lg,
      AppSpacing.lg,
      AppSpacing.lg,
      AppSpacing.xxl,
    ),
  });

  final String departmentId;
  final bool canManage;

  /// Id del usuario actual. Para el empleado (`!canManage`) determina qué
  /// tareas puede marcar: las suyas o las que no tienen responsable.
  final String? currentUserId;

  /// Sub-equipo fijo (migración 030): el tablero solo muestra/crea tareas de
  /// ese sub-equipo y oculta el filtro. Si es null, el tablero es del área y
  /// (para quien administra) aparece un filtro por sub-equipo.
  final String? fixedSubTeamId;
  final String? fixedSubTeamName;

  final EdgeInsets padding;

  @override
  State<TaskBoardBody> createState() => _TaskBoardBodyState();
}

class _TaskBoardBodyState extends State<TaskBoardBody> {
  List<DeptTask> _tasks = const [];
  List<UserProfile> _members = const [];
  List<SubTeam> _subTeams = const [];

  /// Filtro de sub-equipo activo: null = todas, 'none' = solo de área, o el
  /// id de un sub-equipo. Con [TaskBoardBody.fixedSubTeamId] queda fijo.
  String? _subTeamFilter;

  BoardFilter _filter = BoardFilter.all;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  /// El director gestiona y revisa, pero no marca tareas como completadas.
  bool _isDirector = false;

  String? get _effectiveSubTeamId => widget.fixedSubTeamId ?? _subTeamFilter;

  @override
  void initState() {
    super.initState();
    _subTeamFilter = widget.fixedSubTeamId;
    _load();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final role = await Session.getCachedRole();
    if (!mounted) return;
    setState(() => _isDirector = role == AppRole.director);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Las tareas se piden ya filtradas por sub-equipo (el sub-líder no debe
      // recibir las de otros sub-equipos). El resto de filtros ("Mías", "Por
      // revisar"...) se aplican en el cliente.
      final results = await Future.wait([
        DeptTaskApi.list(
          departmentId: widget.departmentId,
          subTeamId: _effectiveSubTeamId,
        ),
        if (widget.canManage)
          TeamApi.members(widget.departmentId)
        else
          Future.value(<UserProfile>[]),
        if (widget.canManage && widget.fixedSubTeamId == null)
          SubTeamApi.list(widget.departmentId)
        else
          Future.value(<SubTeam>[]),
      ]);
      if (!mounted) return;
      setState(() {
        _tasks = results[0] as List<DeptTask>;
        // Asignables al desglosar: los empleados del área y, al final, el
        // propio manager (por si se queda un tramo).
        final people = results[1] as List<UserProfile>;
        _members = [
          ...people.where((u) => u.role == AppRole.employee),
          ...people.where((u) => u.role == AppRole.manager),
        ];
        _subTeams = results[2] as List<SubTeam>;
        _loading = false;
      });
    } on TeamException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  void _setSubTeamFilter(String? value) {
    if (_subTeamFilter == value) return;
    setState(() => _subTeamFilter = value);
    _load();
  }

  List<DeptTask> _subtasksOf(String id) =>
      _tasks.where((t) => t.parentId == id).toList();

  bool _matches(DeptTask t) =>
      _filter.matches(t, currentUserId: widget.currentUserId);

  /// Tareas principales que pasan el filtro, ya sea por sí mismas o porque
  /// alguna de sus subtareas lo pasa (así una subtarea "por revisar" no
  /// queda huérfana). Las subtareas se muestran completas bajo su tarea.
  List<DeptTask> get _visibleTopLevel => _tasks
      .where((t) => !t.isSubtask)
      .where((t) => _matches(t) || _subtasksOf(t.id).any(_matches))
      .toList();

  /// Quién puede marcar una tarea como completada.
  ///
  /// - manager (`canManage` y no director): cualquier tarea.
  /// - director: NUNCA. Solo revisa (aprueba o devuelve) lo que le llega.
  /// - empleado: SOLO las tareas asignadas específicamente a él. Una tarea
  ///   sin responsable, o de otra persona, no la puede tocar.
  bool _canComplete(DeptTask t) {
    if (_isDirector) return false;
    if (widget.canManage) return true;
    // Una aprobación del manager cierra la tarea para el empleado. Si necesita
    // cambios, la devolución la reabre y permite una nueva entrega.
    if (t.reviewStatus == DeptTaskReviewStatus.aprobada) return false;
    final a = t.assignedTo;
    return a != null &&
        widget.currentUserId != null &&
        a.id == widget.currentUserId;
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _toggleDone(DeptTask t) async {
    // Evita reentradas por doble toque en la casilla mientras hay una
    // operación (o su cadena de diálogos) en curso.
    if (_busy) return;
    final bool markingDone = !t.isDone;

    // Desmarcar / reabrir: sin confirmación.
    if (!markingDone) {
      setState(() => _busy = true);
      try {
        await DeptTaskApi.setStatus(t.id, DeptTaskStatus.pendiente);
        await _load();
        if (mounted) setState(() => _busy = false);
      } on TeamException catch (e) {
        if (!mounted) return;
        setState(() => _busy = false);
        _snack(e.message);
      }
      return;
    }

    // Completar: confirmación (+ evidencia si la tarea la exige).
    final ok = await showAppConfirmDialog(
      context,
      title: 'Completar tarea',
      message: t.requiresEvidence
          ? '"${t.title}" requiere adjuntar una foto como evidencia. '
              'Podrás revisarla antes de enviarla.'
          : '¿Marcar "${t.title}" como completada?',
      confirmLabel: t.requiresEvidence ? 'Elegir foto' : 'Completar',
    );
    if (ok != true) return;

    File? evidence;
    if (t.requiresEvidence) {
      // Seleccionar la foto NO la sube: el usuario la revisa en una pantalla
      // de confirmación (previsualización + "Enviar" / "Cambiar" / "Cancelar")
      // y solo al confirmar se envía al servidor.
      evidence = await _pickAndConfirmEvidence(t);
      if (evidence == null) return; // canceló o no eligió foto
    }

    if (_busy) return;
    setState(() => _busy = true);
    try {
      await DeptTaskApi.complete(t.id, evidence: evidence);
      await _load();
      if (mounted) {
        setState(() => _busy = false);
        celebrateBurst(context);
        _snack(widget.canManage
            ? 'Evidencia enviada. Tarea completada.'
            : 'Evidencia enviada. Tu manager la revisará.');
      }
    } on TeamException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack(e.message);
    }
  }

  /// Deja elegir una foto de evidencia y la muestra en una hoja de
  /// confirmación con previsualización. Devuelve el archivo solo si el usuario
  /// pulsa "Enviar evidencia"; `null` si cancela o no elige ninguna. "Cambiar
  /// foto" reabre el selector sin enviar nada.
  Future<File?> _pickAndConfirmEvidence(DeptTask t) async {
    final picker = ImagePicker();
    while (true) {
      final XFile? picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 80,
      );
      if (picked == null || !mounted) return null; // canceló el selector
      final file = File(picked.path);

      final action = await showModalBottomSheet<EvidenceChoice>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.surface,
        builder: (_) => EvidenceConfirmSheet(taskTitle: t.title, file: file),
      );
      if (action == EvidenceChoice.confirm) return file;
      if (action == EvidenceChoice.replace) continue; // elegir otra
      return null; // canceló
    }
  }

  /// Manager/director aprueba o devuelve una tarea pendiente de revisión.
  Future<void> _review(DeptTask t, {required bool approve}) async {
    String? note;
    if (!approve) {
      final controller = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Devolver tarea'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Motivo (qué falta o corregir)',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancelar',
                  style: TextStyle(color: AppColors.textMuted)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Devolver', style: TextStyle(color: AppColors.error)),
            ),
          ],
        ),
      );
      if (ok != true) return;
      note = controller.text.trim();
      if (note.isEmpty) {
        _snack('Indica el motivo del rechazo.');
        return;
      }
    }
    setState(() => _busy = true);
    try {
      await DeptTaskApi.review(t.id, approve: approve, note: note);
      await _load();
      if (mounted) setState(() => _busy = false);
    } on TeamException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack(e.message);
    }
  }

  Future<void> _openDetail(DeptTask t) async {
    final canComment = widget.canManage ||
        (t.assignedTo != null && t.assignedTo!.id == widget.currentUserId);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TaskDetailSheet(task: t, canComment: canComment),
      ),
    );
    if (mounted) _load();
  }

  void _openEvidence(DeptTask t) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EvidenceViewer(
          url: DeptTaskApi.evidenceUrl(t.id),
          title: 'Evidencia · ${t.title}',
        ),
      ),
    );
  }

  Future<void> _openForm({String? parentId, DeptTask? existing}) async {
    // El director elige departamento (la tarea le cae al manager); para eso
    // el formulario necesita la lista de departamentos.
    final isDirector = await Session.getCachedRole() == AppRole.director;
    List<DepartmentInfo> departments = const [];
    if (isDirector && parentId == null) {
      try {
        departments = await TeamApi.listDepartments();
      } on TeamException catch (e) {
        _snack(e.message);
        return;
      }
    }
    if (!mounted) return;
    // Sub-equipo fijo si el tablero venía acotado a uno (sub-líder) o si el
    // filtro está puesto en un sub-equipo concreto.
    final String? fixedId = widget.fixedSubTeamId ??
        (_subTeamFilter != null && _subTeamFilter != 'none'
            ? _subTeamFilter
            : null);
    final String? fixedName = fixedId == null
        ? null
        : (widget.fixedSubTeamName ??
            _subTeams
                .cast<SubTeam?>()
                .firstWhere((s) => s?.id == fixedId, orElse: () => null)
                ?.name);
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TaskFormScreen(
          departmentId: widget.departmentId,
          parentId: parentId,
          existing: existing,
          members: _members,
          asDirector: isDirector,
          departments: departments,
          subTeams: parentId == null ? _subTeams : const [],
          fixedSubTeamId: fixedId,
          fixedSubTeamName: fixedName,
        ),
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _delete(DeptTask t) async {
    final ok = await showAppConfirmDialog(
      context,
      title: 'Eliminar tarea',
      message: t.subtaskCount > 0
          ? 'Se eliminará la tarea y sus ${t.subtaskCount} subtareas. ¿Continuar?'
          : '¿Eliminar esta tarea?',
      confirmLabel: 'Eliminar',
      danger: true,
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await DeptTaskApi.delete(t.id);
      await _load();
      if (mounted) setState(() => _busy = false);
    } on TeamException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack(e.message);
    }
  }

  Future<void> _cycleStatus(DeptTask t) async {
    const order = [
      DeptTaskStatus.pendiente,
      DeptTaskStatus.enProgreso,
      DeptTaskStatus.completada
    ];
    final next = order[(order.indexOf(t.status) + 1) % order.length];
    setState(() => _busy = true);
    try {
      await DeptTaskApi.setStatus(t.id, next);
      await _load();
      if (mounted) setState(() => _busy = false);
    } on TeamException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingState();
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);

    final visible = _visibleTopLevel;
    final hasAny = _tasks.isNotEmpty;

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.accent,
      child: ListView(
        padding: widget.padding,
        children: [
          BoardSummary(
            tasks: _tasks,
            selected: _filter,
            onSelect: (f) => setState(() => _filter = f),
            currentUserId: widget.currentUserId,
            showMine: widget.currentUserId != null,
            trailing: widget.canManage
                ? _NewTaskButton(onPressed: _busy ? null : () => _openForm())
                : null,
          ),
          if (widget.fixedSubTeamId == null && _subTeams.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _stChip('Todos', _subTeamFilter == null,
                      () => _setSubTeamFilter(null)),
                  _stChip('De área', _subTeamFilter == 'none',
                      () => _setSubTeamFilter('none')),
                  for (final s in _subTeams)
                    _stChip(s.name, _subTeamFilter == s.id,
                        () => _setSubTeamFilter(s.id)),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          if (!hasAny)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xxl),
              child: EmptyState(
                icon: Icons.playlist_add_check_rounded,
                title: 'La escaleta está vacía',
                message: widget.canManage
                    ? 'Crea la primera tarea del equipo.'
                    : 'Cuando tu manager cree tareas, aparecerán aquí.',
                action: widget.canManage
                    ? OutlinedButton.icon(
                        onPressed: _busy ? null : () => _openForm(),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Nueva tarea'),
                      )
                    : null,
              ),
            )
          else if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xxl),
              child: EmptyState(
                icon: Icons.filter_list_off_rounded,
                title: 'Nada en "${_filter.label}"',
                message: 'Prueba con otro filtro.',
                action: OutlinedButton(
                  onPressed: () => setState(() => _filter = BoardFilter.all),
                  child: const Text('Ver todas'),
                ),
              ),
            )
          else
            for (final t in visible) ...[
              _card(t),
              for (final (i, s) in _subtasksOf(t.id).indexed)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: SubtaskConnector(
                    isLast: i == _subtasksOf(t.id).length - 1,
                    child: _card(s, dense: true),
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
            ],
        ],
      ),
    );
  }

  Widget _stChip(String label, bool selected, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: AppSpacing.sm),
        child: AppFilterChip(label: label, selected: selected, onTap: onTap),
      );

  Widget _card(DeptTask t, {bool dense = false}) => TaskBoardCard(
        task: t,
        canManage: widget.canManage,
        canComplete: _canComplete(t),
        isDirector: _isDirector,
        busy: _busy,
        dense: dense,
        onToggleDone: () => _toggleDone(t),
        onCycleStatus: () => _cycleStatus(t),
        onEdit: () => _openForm(existing: t),
        onAddSubtask: dense ? null : () => _openForm(parentId: t.id),
        onDelete: () => _delete(t),
        onOpen: () => _openDetail(t),
        onViewEvidence: t.hasEvidence ? () => _openEvidence(t) : null,
        onApprove: () => _review(t, approve: true),
        onReject: () => _review(t, approve: false),
      );
}

/// Botón compacto "+ Nueva" de la cabecera (manager / director).
class _NewTaskButton extends StatelessWidget {
  const _NewTaskButton({required this.onPressed});
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.add_rounded, size: 18),
      label: const Text('Nueva'),
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.brandBlue,
        foregroundColor: AppColors.onBrand,
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      ),
    );
  }
}
