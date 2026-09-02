import 'dart:async';
import 'dart:convert';

import 'package:brl_task4/ResourceM/Resources.dart';
import 'package:brl_task4/screens/chat.dart';
import 'package:brl_task4/screens/dashboard.dart';
import "package:flutter/material.dart";
import 'package:http/http.dart' as http;
import '../design/design.dart';
import '../utils/api_config.dart';
import '../utils/Routes.dart';
import 'MResign.dart';
import 'login.dart';
import 'manageMembers.dart';
import 'addTask.dart';
import 'directChat.dart';
import '../utils/session.dart';
class t_detail extends StatefulWidget {
   t_detail({super.key, required this.team});
  dynamic team;
  @override
  State<t_detail> createState() => _t_detailState();
}

class _t_detailState extends State<t_detail> {
  dynamic teams;
  // Corregido: antes se inicializaba con la variable global `name`, que
  // solo se llenaba al visitar la pestaña "Equipos" y se perdía al
  // reiniciar la app. Eso hacía que quien acababa de crear un equipo (o
  // reabría la app) a veces no se reconociera como admin de inmediato.
  // Ahora se resuelve de forma confiable en _loadMyEmail().
  String? email;
  // Un equipo puede tener varios admins (antes era un único "líder" en
  // `leaderEmail`). El backend expone la lista completa en `admins`; por
  // compatibilidad, si todavía no manda ese campo, se usa `leaderEmail`
  // como admin único para no romper equipos creados con la versión previa.
  List<String> admins = [];
  String? leaderEmail;
  String? leaderName;
  String? teamName;
  String? teamCode;
  String? teamId;
  // Refresca el equipo en segundo plano cada pocos segundos (misma idea que
  // el chat y las notificaciones): así, si el líder cambia, alguien entra o
  // sale, o se agrega/quita una tarea desde otro dispositivo, esta pantalla
  // lo refleja sola, sin depender de que el usuario haga swipe-to-refresh.
  // Usa la misma ruta que ya usa el pull-to-refresh (_refreshTeam), que solo
  // actualiza el estado si la petición tiene éxito, así que un fallo de red
  // pasajero no borra ni "vuelve loca" la pantalla.
  Timer? _pollTimer;
  @override
  void initState() {
    super.initState();
    // `widget.team` ya viene completo (desde showTeams o desde la
    // respuesta de createTeam/joinTeam), así que se procesa una sola vez
    // aquí en lugar de en cada build().
    teams = widget.team;
    data(teams);
    _loadMyEmail();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _refreshTeam());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  /// Resuelve "quién soy" de forma confiable: primero intenta la variable
  /// global `name` (rápido, si ya se cargó en esta sesión de la app),
  /// luego el correo cacheado en almacenamiento seguro (persiste entre
  /// reinicios) y, como último recurso, lo pide a /user/me. Así, quien
  /// acaba de crear el equipo se reconoce como admin/líder al instante,
  /// sin depender de haber visitado antes la pestaña de Equipos.
  Future<void> _loadMyEmail() async {
    if (name != null && name!.isNotEmpty) {
      if (mounted) setState(() => email = name);
      return;
    }
    final token = await secureStorage.readSecureData(key);
    final resolved = await Session.resolveEmail(token as String?);
    if (resolved == null) return;
    name = resolved;
    if (mounted) setState(() => email = resolved);
  }

  List<dynamic>? domains;
  List<String> teamMembers = [];

  // Insensible a mayúsculas/minúsculas, igual que la comparación que hace
  // el backend (strcasecmp) y que _isAdmin() en manageMembers.dart. Antes
  // era una comparación exacta contra un único leader_email; ahora se
  // compara contra la lista completa de admins del equipo, que puede tener
  // más de uno.
  bool get _isAdmin =>
      email != null &&
      admins.any((a) => a.toLowerCase() == email!.toLowerCase());

  // Un admin solo puede abandonar el equipo si queda al menos otro admin
  // después de irse; si es el único, primero debe ascender a alguien más.
  bool get _isOnlyAdmin => admins.length <= 1 && _isAdmin;

  String _displayName(String emailAddr) =>
      emailAddr.contains('@') ? emailAddr.substring(0, emailAddr.indexOf('@')) : emailAddr;

  /// Actualiza una tarea de equipo por id: reasignarla (nueva lista
  /// `newEmails`, una o más personas), reprogramarla (nuevo `description`
  /// y/o `deadline`), o marcarla como completa (`completed: true`). Solo se
  /// envían los campos no nulos, así que cada acción del menú llama a esto
  /// con solo lo que cambió.
  Future<bool> _updateTask(
    String taskId, {
    List<String>? newEmails,
    String? description,
    String? deadline,
    bool? completed,
  }) async {
    dynamic storedValue = await secureStorage.readSecureData(key);
    try {
      final body = <String, String>{};
      if (newEmails != null && newEmails.isNotEmpty) {
        body['emails'] = newEmails.join(',');
      }
      if (description != null) body['description'] = description;
      if (deadline != null) body['deadline'] = deadline;
      if (completed != null) body['completed'] = completed.toString();

      final response = await http.post(
        Uri.parse('$kBaseUrl/team/taskUpdate/$taskId'),
        headers: <String, String>{'Authorization': storedValue ?? ''},
        body: body,
      );
      if (response.statusCode == 200) {
        return true;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo actualizar la tarea (${response.statusCode})')),
        );
      }
      return false;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error de red al actualizar la tarea')),
        );
      }
      return false;
    }
  }

  Future<void> _confirmDeleteTeam() async {
    final bool? confirmed = await showAppConfirmDialog(
      context,
      title: 'Eliminar equipo',
      message: 'Se eliminará "$teamName" junto con sus áreas, tareas y recursos. '
          'Esta acción no se puede deshacer.',
      confirmLabel: 'Eliminar',
      danger: true,
    );

    if (confirmed != true) return;
    await _deleteTeam();
  }

  Future<void> _deleteTeam() async {
    dynamic storedValue = await secureStorage.readSecureData(key);
    try {
      final response = await http.post(
        Uri.parse('$kBaseUrl/team/deleteTeam/$teamId'),
        headers: <String, String>{'Authorization': storedValue ?? ''},
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Equipo eliminado')),
        );
        Navigator.pushNamedAndRemoveUntil(context, MyRoutes.BottomNavBar, (route) => false);
      } else if (response.statusCode == 403) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Solo un admin puede eliminar el equipo')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo eliminar el equipo (${response.statusCode})')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error de red al eliminar el equipo')),
      );
    }
  }

  // Ya no es async ni usa setState: se llama una sola vez desde initState()
  // (antes del primer build), así que basta con asignar los campos
  // directamente. Antes se llamaba desde dentro de build() envuelto en
  // setState(), lo cual es un antipatrón de Flutter (setState durante el
  // build) y puede lanzar el error "setState() or markNeedsBuild() called
  // during build".
  void data(dynamic teams) {
    teamId = teams['_id'];
    teamName = teams['teamName'];
    domains = teams['domains'] ?? [];
    leaderEmail = teams['leaderEmail'];
    leaderName = teams['leaderName'];
    teamCode = teams['teamCode'];
    teamMembers = List<String>.from(
      (teams['teamMembers'] as List?)?.map((m) => m.toString()) ?? const [],
    );
    final adminsFromApi = (teams['admins'] as List?)
        ?.map((a) => a.toString())
        .where((a) => a.isNotEmpty)
        .toList();
    admins = (adminsFromApi != null && adminsFromApi.isNotEmpty)
        ? adminsFromApi
        : (leaderEmail != null && leaderEmail!.isNotEmpty ? [leaderEmail!] : []);
  }

  /// Refresca los datos de este equipo (para reflejar cambios recientes:
  /// nuevos miembros, tareas, o el propio ascenso a líder si se transfirió
  /// el liderazgo) sin salir de la pantalla.
  Future<void> _refreshTeam() async {
    final storedValue = await secureStorage.readSecureData(key);
    try {
      final response = await http.get(
        Uri.parse('$kBaseUrl/team/showTeams'),
        headers: <String, String>{'Authorization': storedValue ?? ''},
      );
      if (!mounted || response.statusCode != 200) return;
      final decoded = jsonDecode(response.body);
      final List<dynamic> teamsList = decoded['teams'] ?? [];
      final match = teamsList.firstWhere(
        (t) => t['_id']?.toString() == teamId,
        orElse: () => null,
      );
      if (match != null) {
        setState(() => data(match));
      }
    } catch (_) {
      // Si falla el refresco simplemente se mantienen los datos actuales.
    }
  }

  void _openTaskPicker(int domainIndex) {
    final domain = domains![domainIndex];
    final List tasks = (domain['tasks'] as List?) ?? [];
    // Antes solo se listaban las pendientes; ahora se listan todas (también
    // las ya completadas) para poder verlas y seguir gestionándolas —
    // reasignar, reprogramar o revisar su descripción — desde el mismo
    // lugar.
    final allIndexes = List<int>.generate(tasks.length, (i) => i);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.textMuted,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                Text(
                  "Gestionar tareas",
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
                ),
                Text(
                  "Área: ${domain['name']}",
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 12),
                if (allIndexes.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      "Sin tareas en esta área todavía.",
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: allIndexes.length,
                      separatorBuilder: (_, __) => Divider(color: AppColors.surfaceBorder, height: 1),
                      itemBuilder: (context, i) {
                        final taskIndex = allIndexes[i];
                        final t = tasks[taskIndex];
                        final assignedTo = (t['assignedTo'] ?? '').toString();
                        final bool done = t['completed'] == true;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            done ? Icons.check_circle : Icons.radio_button_unchecked,
                            color: done ? AppColors.success : AppColors.error,
                          ),
                          title: Text(
                            t['description'] ?? '',
                            style: TextStyle(
                              color: done ? AppColors.textMuted : AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                              decoration: done ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          subtitle: Text(
                            "Para: ${assignedTo.contains('@') ? assignedTo.substring(0, assignedTo.indexOf('@')) : assignedTo}  ·  Vence: ${t['deadline']}",
                            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                          ),
                          trailing: IconButton(
                            icon: Icon(Icons.chevron_right, color: AppColors.textMuted),
                            tooltip: 'Opciones',
                            onPressed: () {
                              Navigator.pop(sheetContext);
                              _openTaskActionsMenu(domain, tasks, taskIndex);
                            },
                          ),
                          onTap: () {
                            Navigator.pop(sheetContext);
                            _openTaskActionsMenu(domain, tasks, taskIndex);
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Menú de acciones para una tarea (se abre al presionar el ">" de una
  /// fila en "Gestionar tareas"): reasignarla, reprogramarla (texto y/o
  /// fecha), o marcarla como completa.
  void _openTaskActionsMenu(dynamic domain, List tasks, int taskIndex) {
    final t = tasks[taskIndex];
    final String? taskId = t['id']?.toString();
    final bool done = t['completed'] == true;

    if (taskId == null || taskId.isEmpty) {
      // Con un backend desactualizado, las tareas podrían no traer id
      // todavía; sin id no hay forma segura de saber cuál editar.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo identificar la tarea')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.textMuted,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                Text(
                  t['description'] ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.swap_horiz, color: AppColors.accent),
                  title: Text('Volver a asignar tarea', style: TextStyle(color: AppColors.textPrimary)),
                  subtitle: Text('Elige a quién asignársela', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _openReassignDialog(domain, tasks, taskIndex, taskId);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.edit_calendar_outlined, color: AppColors.accent),
                  title: Text('Reprogramar la tarea', style: TextStyle(color: AppColors.textPrimary)),
                  subtitle: Text('Cambia el texto y/o la fecha de entrega', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _openRescheduleDialog(domain, tasks, taskIndex, taskId);
                  },
                ),
                if (!done)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.check_circle_outline, color: AppColors.success),
                    title: Text('Marcar tarea como completa', style: TextStyle(color: AppColors.textPrimary)),
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      final success = await _updateTask(taskId, completed: true);
                      if (success) {
                        setState(() => tasks[taskIndex]['completed'] = true);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('"${t['description']}" marcada como completada')),
                          );
                        }
                      }
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Diálogo de "Volver a asignar tarea": elige a una o más personas de la
  /// misma área para asignársela (el backend valida de nuevo que cada una
  /// pertenezca a ella). Se puede elegir a la misma persona que ya la tenía
  /// asignada — no está restringido a "otro" miembro. Al confirmar, la
  /// tarea vuelve a quedar pendiente (se desmarca como hecha si estaba
  /// completa) y le llega la notificación de reasignación a cada persona
  /// elegida; si se elige a más de una, la tarea se reparte: cada quien
  /// recibe su propia copia.
  void _openReassignDialog(dynamic domain, List tasks, int taskIndex, String taskId) {
    final List<String> members = ((domain['members'] as List?) ?? [])
        .map((m) => m.toString())
        .toList();
    final currentAssignee = (tasks[taskIndex]['assignedTo'] ?? '').toString();
    final Set<String> selected = <String>{
      if (members.contains(currentAssignee)) currentAssignee,
    };
    bool submitting = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              title: Text('Volver a asignar tarea', style: TextStyle(color: AppColors.textPrimary)),
              content: members.isEmpty
                  ? Text(
                      'Esta área no tiene más miembros a quién reasignar.',
                      style: TextStyle(color: AppColors.textMuted),
                    )
                  : SizedBox(
                      width: double.maxFinite,
                      child: ListView(
                        shrinkWrap: true,
                        children: members.map((m) {
                          final display = m.contains('@') ? m.substring(0, m.indexOf('@')) : m;
                          return CheckboxListTile(
                            value: selected.contains(m),
                            activeColor: AppColors.accent,
                            title: Text(display, style: TextStyle(color: AppColors.textPrimary)),
                            controlAffinity: ListTileControlAffinity.leading,
                            onChanged: submitting
                                ? null
                                : (checked) => setDialogState(() {
                                      if (checked == true) {
                                        selected.add(m);
                                      } else {
                                        selected.remove(m);
                                      }
                                    }),
                          );
                        }).toList(),
                      ),
                    ),
              actions: [
                TextButton(
                  onPressed: submitting ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: (submitting || selected.isEmpty)
                      ? null
                      : () async {
                          setDialogState(() => submitting = true);
                          final success = await _updateTask(taskId, newEmails: selected.toList());
                          if (!mounted) return;
                          if (success) {
                            // Reasignar puede crear filas de tarea nuevas
                            // (una por persona adicional elegida) y siempre
                            // desmarca la tarea como completa, así que se
                            // refresca el equipo entero en vez de solo
                            // parchear esta fila en memoria.
                            await _refreshTeam();
                            if (!mounted) return;
                            Navigator.pop(dialogContext);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  selected.length > 1 ? 'Tarea reasignada a ${selected.length} personas' : 'Tarea reasignada',
                                ),
                              ),
                            );
                          } else {
                            setDialogState(() => submitting = false);
                          }
                        },
                  child: Text(submitting ? 'Guardando…' : 'Reasignar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Diálogo de "Reprogramar la tarea": deja editar tanto el texto de la
  /// tarea como su fecha de entrega, y guarda solo lo que haya cambiado.
  void _openRescheduleDialog(dynamic domain, List tasks, int taskIndex, String taskId) {
    final t = tasks[taskIndex];
    final descriptionController = TextEditingController(text: (t['description'] ?? '').toString());
    final deadlineController = TextEditingController(text: (t['deadline'] ?? '').toString());
    bool submitting = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> pickDeadline() async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: dialogContext,
                initialDate: now,
                firstDate: now.subtract(const Duration(days: 1)),
                lastDate: DateTime(now.year + 5),
              );
              if (picked == null) return;
              final dd = picked.day.toString().padLeft(2, '0');
              final mm = picked.month.toString().padLeft(2, '0');
              // Mismo formato dd-MM-yyyy que usa "Agregar tarea", para no
              // romper el parseo/orden de fechas en el resto de la app.
              setDialogState(() => deadlineController.text = '$dd-$mm-${picked.year}');
            }

            return AlertDialog(
              backgroundColor: AppColors.surface,
              title: Text('Reprogramar la tarea', style: TextStyle(color: AppColors.textPrimary)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: descriptionController,
                      enabled: !submitting,
                      maxLines: 3,
                      style: TextStyle(color: AppColors.textPrimary),
                      decoration: const InputDecoration(labelText: 'Descripción de la tarea'),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: deadlineController,
                      enabled: !submitting,
                      readOnly: true,
                      onTap: submitting ? null : pickDeadline,
                      style: TextStyle(color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Fecha de entrega',
                        suffixIcon: Icon(Icons.calendar_month_outlined),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: submitting ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: submitting
                      ? null
                      : () async {
                          final newDescription = descriptionController.text.trim();
                          final newDeadline = deadlineController.text.trim();
                          if (newDescription.isEmpty || newDeadline.isEmpty) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              const SnackBar(content: Text('Completa la descripción y la fecha')),
                            );
                            return;
                          }
                          setDialogState(() => submitting = true);
                          final success = await _updateTask(
                            taskId,
                            description: newDescription,
                            deadline: newDeadline,
                          );
                          if (!mounted) return;
                          if (success) {
                            setState(() {
                              tasks[taskIndex]['description'] = newDescription;
                              tasks[taskIndex]['deadline'] = newDeadline;
                            });
                            Navigator.pop(dialogContext);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Tarea reprogramada')),
                            );
                          } else {
                            setDialogState(() => submitting = false);
                          }
                        },
                  child: Text(submitting ? 'Guardando…' : 'Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // `teams`/`domains`/etc. ya se procesaron en initState(); aquí solo se
    // construye la UI con el estado actual (no se debe llamar setState()
    // dentro de build()).
    return AppScaffold(
        padding: EdgeInsets.zero,
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(0.6, 0.8),
              end: Alignment(0.4, 0.31),
              colors: [AppColors.bgBase, AppColors.brandNavy],
            ),
          ),
          child: Column(
            children:[
              const SizedBox(height: 20,),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    Text("$teamName",textAlign: TextAlign.center,style: TextStyle(color:AppColors.textPrimary,fontSize: 30,fontWeight: FontWeight.w800 ),),
                    const SizedBox(height: 6,),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 16,
                      runSpacing: 4,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.shield_outlined, size: 15, color: AppColors.textMuted),
                            const SizedBox(width: 4),
                            Text(
                              admins.isEmpty
                                  ? ""
                                  : (admins.length == 1
                                      ? "Admin: ${_displayName(admins.first)}"
                                      : "Admins: ${admins.map(_displayName).join(', ')}"),
                              style: TextStyle(color: AppColors.textMuted, fontSize: 14,fontWeight: FontWeight.w600 ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.tag, size: 15, color: AppColors.textMuted),
                            const SizedBox(width: 4),
                            Text(
                              teamCode ?? '',
                              style: TextStyle(color: AppColors.textMuted, fontSize: 14,fontWeight: FontWeight.w600 ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height:16),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refreshTeam,
                  child: (domains == null)
                      ? const LoadingState()
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: domains!.length + 1,
                          itemBuilder: (context, index) {
                            if (index == domains!.length) {
                              return _buildActionsCard(context);
                            }
                            return _buildDomainCard(context, index);
                          },
                        ),
                ),
              ),
            ],
        ),
        ),
    );
  }

  /// Abre un chat privado 1 a 1 con `peerEmail` (al tocar el correo de un
  /// integrante de un área). Usa [DirectChatScreen], que solo trae los
  /// mensajes entre el usuario actual y esa persona — a diferencia del
  /// chat de equipo (chat.dart), que ven todos los integrantes.
  void _openDirectChat(String peerEmail) {
    final myEmail = email;
    if (myEmail == null || myEmail.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DirectChatScreen(peerEmail: peerEmail, myEmail: myEmail),
      ),
    );
  }

  Widget _buildDomainCard(BuildContext context, int index) {
    final domain = domains![index];
    final List members = (domain['members'] as List?) ?? [];
    final List tasks = (domain['tasks'] as List?) ?? [];
    final int pendingCount = tasks.where((t) => t['completed'] == false).length;
    final int doneCount = tasks.length - pendingCount;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.textPrimary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.workspaces_outline, color: AppColors.accent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  domain['name'] ?? '',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (members.isEmpty)
            Text("Sin miembros todavía", style: TextStyle(color: AppColors.textMuted, fontSize: 13))
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: members.map((m) {
                final s = m.toString();
                final bool isMe = email != null && s.toLowerCase() == email!.toLowerCase();
                return InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: isMe ? null : () => _openDirectChat(s),
                  child: Chip(
                    backgroundColor: AppColors.surface,
                    visualDensity: VisualDensity.compact,
                    avatar: Icon(Icons.person, size: 14, color: AppColors.textMuted),
                    label: Text(
                      s.contains('@') ? s.substring(0, s.indexOf('@')) : s,
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 12),
                    ),
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 14),
          Row(
            children: [
              _statusPill(Icons.pending_actions, "$pendingCount pendientes", AppColors.error),
              const SizedBox(width: 8),
              _statusPill(Icons.check_circle, "$doneCount hechas", AppColors.success),
            ],
          ),
          const SizedBox(height: 10),
          if (tasks.isEmpty)
            Text("Sin tareas en esta área todavía", style: TextStyle(color: AppColors.textMuted, fontSize: 13))
          else
            Column(
              children: tasks.map<Widget>((t) {
                final assignedTo = (t['assignedTo'] ?? '').toString();
                final bool done = t['completed'] != false;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        done ? Icons.check_circle : Icons.radio_button_unchecked,
                        size: 18,
                        color: done ? AppColors.success : AppColors.error,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t['description'] ?? '',
                              style: TextStyle(
                                color: done ? AppColors.textMuted : AppColors.textPrimary,
                                fontSize: 14,
                                decoration: done ? TextDecoration.lineThrough : null,
                              ),
                            ),
                            Text(
                              "Para: ${assignedTo.contains('@') ? assignedTo.substring(0, assignedTo.indexOf('@')) : assignedTo}  ·  Vence: ${t['deadline']}",
                              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          if (_isAdmin && tasks.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _openTaskPicker(index),
                icon: const Icon(Icons.checklist, size: 18),
                label: const Text("Gestionar tareas"),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusPill(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildActionsCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.textPrimary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: !_isAdmin
          ? Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                // "Salir" y "Renunciar" llevan a la misma pantalla de
                // confirmación: al aceptar, solo esa persona abandona el
                // equipo (los demás integrantes siguen ahí). Antes "Salir"
                // abría un formulario de permiso/ausencia sin relación con
                // dejar el equipo; ahora ambos botones hacen lo mismo.
                _actionButton("Salir", Icons.logout, () {
                  // Se usa push (no pushReplacement) para que, si el
                  // usuario cancela en la pantalla de confirmación, el
                  // botón "Cancelar" lo regrese aquí (detalle del equipo)
                  // en vez de saltarse esta pantalla al hacer pop().
                  Navigator.push(context,
                      MaterialPageRoute(builder: (context) => Mresign(teamId: teamId)))
                      .then((_) => _refreshTeam());
                }),
                _actionButton("Renunciar", Icons.person_remove_outlined, () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (context) => Mresign(teamId: teamId)))
                      .then((_) => _refreshTeam());
                }),
                _actionButton("Chat", Icons.chat_bubble_outline, () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(
                    teamId: teamId!,
                    myEmail: email ?? '',
                    teamName: teamName,
                  )));
                }),
                _actionButton("Recursos", Icons.folder_outlined, () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => ResourceM(teamId!)));
                }),
              ],
            )
          : Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                _actionButton("Agregar tarea", Icons.add_task, () {
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => addTask(teamcode:teamCode, domains: domains)));
                }),
                _actionButton("Chat", Icons.chat_bubble_outline, () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(
                    teamId: teamId!,
                    myEmail: email ?? '',
                    teamName: teamName,
                  )));
                }),
                _actionButton("Recursos", Icons.folder_outlined, () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => ResourceM(teamId!)));
                }),
                _actionButton("Gestionar equipo", Icons.manage_accounts_outlined, () async {
                  // Se espera a que la pantalla de miembros se cierre y luego
                  // se refresca el equipo: así, al agregar o sacar a alguien,
                  // o al ascender/quitar un admin y volver, esta pantalla (y
                  // si se vuelve a abrir "Gestionar equipo") siempre muestra
                  // la lista real y actualizada, en vez de la que se cargó
                  // al entrar aquí.
                  await Navigator.push(context,
                      MaterialPageRoute(builder: (context) =>
                          ManageMembers(
                            teamId: teamId!,
                            teamName: teamName ?? '',
                            currentUserEmail: email ?? '',
                            admins: admins,
                            members: teamMembers,
                          )));
                  if (mounted) await _refreshTeam();
                }),
                // Un admin puede salir del equipo siempre que no sea el
                // único: si lo es, primero debe ascender a otro miembro
                // desde "Gestionar equipo".
                _actionButton(
                  "Salir",
                  Icons.logout,
                  _isOnlyAdmin
                      ? () => ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Eres el único admin: asciende a otro miembro antes de salir',
                              ),
                            ),
                          )
                      : () {
                          Navigator.push(context,
                              MaterialPageRoute(builder: (context) => Mresign(teamId: teamId)))
                              .then((_) => _refreshTeam());
                        },
                ),
                _actionButton("Eliminar equipo", Icons.delete_outline,
                    _confirmDeleteTeam, danger: true),
              ],
            ),
    );
  }

  Widget _actionButton(String label, IconData icon, VoidCallback onTap, {bool danger = false}) {
    return ElevatedButton.icon(
      onPressed: onTap,
      style: danger
          ? ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.textPrimary,
            )
          : null,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}
