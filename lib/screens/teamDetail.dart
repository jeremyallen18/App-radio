import 'package:doliv_social/ResourceM/Resources.dart';
import 'package:doliv_social/screens/chat.dart';
import "package:flutter/material.dart";
import 'package:http/http.dart' as http;
import '../design/design.dart';
import '../utils/api_config.dart';
import '../utils/Routes.dart';
import 'LResign.dart';
import 'MResign.dart';
import 'addTask.dart';
import 'dashboard.dart';
import 'login.dart';
import 'package:doliv_social/leave approval/leave.dart';
class t_detail extends StatefulWidget {
   t_detail({super.key, required this.team});
  dynamic team;
  @override
  State<t_detail> createState() => _t_detailState();
}

class _t_detailState extends State<t_detail> {
  dynamic teams;
  String? email=name;
  String? leaderEmail;
  String? teamName;
  String? teamCode;
  String? teamId;
  String teamId2="";
  Future<void>? _futureData;
  @override
  void initState() {
    super.initState();
  }
  List<dynamic>? domains;

  bool get _isLeader => email == leaderEmail;

  Future<bool> _markTaskDone(String domainName, String assignedTo, String task) async {
    dynamic storedValue = await secureStorage.readSecureData(key);
    final response = await http.post(
      Uri.parse('$kBaseUrl/team/taskDone'),
      headers: <String, String>{
        'Authorization': storedValue,
      },
      body: {
        "teamCode": teamCode,
        "domainName": domainName,
        "email": assignedTo,
        "task": task,
      },
    );
    if (response.statusCode == 200) {
      return true;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No se pudo marcar la tarea como hecha")),
      );
    }
    return false;
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
          const SnackBar(content: Text('Solo el líder puede eliminar el equipo')),
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

  Future<void> data (dynamic teams) async{
      setState(() {
        teamId = teams['_id'];
        teamId2 = teams['_id'];
        teamName=teams['teamName'];
        domains = teams['domains'] ?? [];
        leaderEmail= teams['leaderEmail'];
        teamCode=teams['teamCode'];
      });
  }

  void _openTaskPicker(int domainIndex) {
    final domain = domains![domainIndex];
    final List tasks = (domain['tasks'] as List?) ?? [];
    final pending = <int>[
      for (int i = 0; i < tasks.length; i++)
        if (tasks[i]['completed'] == false) i,
    ];

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
                  "Elige la tarea a completar",
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
                ),
                Text(
                  "Área: ${domain['name']}",
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 12),
                if (pending.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      "No hay tareas pendientes en esta área.",
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: pending.length,
                      separatorBuilder: (_, __) => const Divider(color: AppColors.surfaceBorder, height: 1),
                      itemBuilder: (context, i) {
                        final taskIndex = pending[i];
                        final t = tasks[taskIndex];
                        final assignedTo = t['assignedTo'] as String;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.radio_button_unchecked, color: AppColors.error),
                          title: Text(
                            t['description'] ?? '',
                            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            "Para: ${assignedTo.contains('@') ? assignedTo.substring(0, assignedTo.indexOf('@')) : assignedTo}  ·  Vence: ${t['deadline']}",
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                          ),
                          trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
                          onTap: () async {
                            Navigator.pop(sheetContext);
                            final success = await _markTaskDone(domain['name'], t['assignedTo'], t['description']);
                            if (success) {
                              setState(() {
                                tasks[taskIndex]['completed'] = true;
                              });
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('"${t['description']}" marcada como completada')),
                                );
                              }
                            }
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

  @override
  Widget build(BuildContext context) {
    setState(() {
      teams = widget.team;
      data(teams);
    });
    return AppScaffold(
        padding: EdgeInsets.zero,
        body: Container(
          decoration: const BoxDecoration(
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
                    Text("$teamName",textAlign: TextAlign.center,style: const TextStyle(color:AppColors.textPrimary,fontSize: 30,fontWeight: FontWeight.w800 ),),
                    const SizedBox(height: 6,),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 16,
                      runSpacing: 4,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.shield_outlined, size: 15, color: AppColors.textMuted),
                            const SizedBox(width: 4),
                            Text(
                              leaderEmail == null ? "" : "Líder: ${leaderEmail!.substring(0,leaderEmail!.indexOf('@'))}",
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 14,fontWeight: FontWeight.w600 ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.tag, size: 15, color: AppColors.textMuted),
                            const SizedBox(width: 4),
                            Text(
                              teamCode ?? '',
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 14,fontWeight: FontWeight.w600 ),
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
                child: FutureBuilder<void>(
                  future: _futureData,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const LoadingState();
                    } else if (snapshot.hasError) {
                      return const ErrorState(
                        message: 'No se pudo cargar la información del equipo.',
                      );
                    } else {
                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ResponsiveCardGrid(
                              children: [
                                for (int i = 0; i < domains!.length; i++)
                                  _buildDomainCard(context, i),
                              ],
                            ),
                            _buildActionsCard(context),
                          ],
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
        ),
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
              const Icon(Icons.workspaces_outline, color: AppColors.accent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  domain['name'] ?? '',
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (members.isEmpty)
            const Text("Sin miembros todavía", style: TextStyle(color: AppColors.textMuted, fontSize: 13))
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: members.map((m) {
                final s = m.toString();
                return Chip(
                  backgroundColor: AppColors.surface,
                  visualDensity: VisualDensity.compact,
                  avatar: const Icon(Icons.person, size: 14, color: AppColors.textMuted),
                  label: Text(
                    s.contains('@') ? s.substring(0, s.indexOf('@')) : s,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
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
            const Text("Sin tareas en esta área todavía", style: TextStyle(color: AppColors.textMuted, fontSize: 13))
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
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          if (_isLeader && pendingCount > 0) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _openTaskPicker(index),
                icon: const Icon(Icons.checklist, size: 18),
                label: const Text("Completar tarea"),
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
      child: !_isLeader
          ? Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                _actionButton("Salir", Icons.logout, () {
                  Navigator.pushReplacement(context, MaterialPageRoute(
                    builder: (context) => ApplyLeave(teamid: teamId2,),),);
                }),
                _actionButton("Renunciar", Icons.person_remove_outlined, () {
                  Navigator.pushReplacement(context,
                      MaterialPageRoute(builder: (context) =>
                          Mresign(teamId: teamId,emailId:leaderEmail)));
                }),
                _actionButton("Chat", Icons.chat_bubble_outline, () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(leaderEmail!)));
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
                  Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(leaderEmail!)));
                }),
                _actionButton("Recursos", Icons.folder_outlined, () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => ResourceM(teamId!)));
                }),
                _actionButton("Gestionar miembros", Icons.manage_accounts_outlined, () {
                  Navigator.pushReplacement(context,
                      MaterialPageRoute(builder: (context) =>
                          Resign(teamId: teamId)));
                }),
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
