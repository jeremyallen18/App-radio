import 'dart:convert';

import "package:flutter/material.dart";
import 'package:http/http.dart' as http;
import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/core/api_config.dart';
import 'package:doliv_social/core/routes.dart';
import 'package:doliv_social/shared/auth/login.dart';
import 'package:doliv_social/shared/teams/team_detail_widgets.dart';

class TeamDetailView extends StatefulWidget {
  const TeamDetailView({super.key, required this.team});
  final dynamic team;
  @override
  State<TeamDetailView> createState() => _TeamDetailViewState();
}

class _TeamDetailViewState extends State<TeamDetailView> {
  dynamic teams;
  String? email;
  String? leaderEmail;
  String? teamName;
  String? teamCode;
  String? teamId;
  String teamId2 = "";
  Future<void>? _futureData;
  @override
  void initState() {
    super.initState();
    _loadCurrentEmail();
  }

  // El correo del usuario autenticado, para saber si es el líder del equipo.
  Future<void> _loadCurrentEmail() async {
    try {
      final token = await secureStorage.readSecureData(key);
      final res = await http.get(
        Uri.parse('$kBaseUrl/user/me'),
        headers: <String, String>{'Authorization': token ?? ''},
      );
      if (res.statusCode == 200 && mounted) {
        setState(() => email = jsonDecode(res.body)['email']?.toString());
      }
    } catch (_) {
      // Sin conexión: se queda sin resolver; _isLeader será false.
    }
  }

  List<dynamic>? domains;

  bool get _isLeader => email == leaderEmail;

  Future<bool> _markTaskDone(
      String domainName, String assignedTo, String task) async {
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
      message:
          'Se eliminará "$teamName" junto con sus áreas, tareas y recursos. '
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
        Navigator.pushNamedAndRemoveUntil(
            context, MyRoutes.bottomNavBar, (route) => false);
      } else if (response.statusCode == 403) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Solo el líder puede eliminar el equipo')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'No se pudo eliminar el equipo (${response.statusCode})')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error de red al eliminar el equipo')),
      );
    }
  }

  Future<void> data(dynamic teams) async {
    setState(() {
      teamId = teams['_id'];
      teamId2 = teams['_id'];
      teamName = teams['teamName'];
      domains = teams['domains'] ?? [];
      leaderEmail = teams['leaderEmail'];
      teamCode = teams['teamCode'];
    });
  }

  void _openTaskPicker(int domainIndex) {
    final domain = domains![domainIndex];
    final List tasks = (domain['tasks'] as List?) ?? [];

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => TeamTaskPickerSheet(
        domain: domain,
        onSelected: (taskIndex) async {
          final t = tasks[taskIndex];
          final success = await _markTaskDone(
              domain['name'], t['assignedTo'], t['description']);
          if (success) {
            setState(() {
              tasks[taskIndex]['completed'] = true;
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content:
                        Text('"${t['description']}" marcada como completada')),
              );
            }
          }
        },
      ),
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
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(0.6, 0.8),
            end: Alignment(0.4, 0.31),
            colors: [AppColors.bgBase, AppColors.brandNavy],
          ),
        ),
        child: Column(
          children: [
            const SizedBox(
              height: 20,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  Text(
                    "$teamName",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 30,
                        fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(
                    height: 6,
                  ),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 16,
                    runSpacing: 4,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.shield_outlined,
                              size: 15, color: AppColors.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            leaderEmail == null
                                ? ""
                                : "Líder: ${leaderEmail!.substring(0, leaderEmail!.indexOf('@'))}",
                            style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 14,
                                fontWeight: FontWeight.w600),
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
                            style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 14,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
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
                                TeamDomainCard(
                                  domain: domains![i],
                                  isLeader: _isLeader,
                                  onCompleteTask: () => _openTaskPicker(i),
                                ),
                            ],
                          ),
                          TeamActionsCard(
                            isLeader: _isLeader,
                            teamId: teamId,
                            teamId2: teamId2,
                            leaderEmail: leaderEmail,
                            onDeleteTeam: _confirmDeleteTeam,
                          ),
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
}
