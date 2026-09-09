
import "dart:async";
import "dart:convert";

import 'teamDetail.dart';
import 'login.dart';
import "package:flutter/material.dart";
import 'package:http/http.dart' as http;
import 'package:brl_task4/models/appbar.dart';
import '../design/design.dart';
import '../utils/api_config.dart';
import '../utils/session.dart';

class dashb_mem extends StatefulWidget {
  const dashb_mem({super.key});
  @override
  State<dashb_mem> createState() => dashb_memState();
}
String? name;
class dashb_memState extends State<dashb_mem> {
  Future<void>? _futureData;
  // Refresca en segundo plano los conteos de "pendientes"/"hechas" por
  // equipo, para que se vean al día si el líder reasigna, reprograma o
  // agrega tareas desde "Gestionar tareas" (misma idea que el polling de
  // teamDetail.dart y de "Mis tareas"). No reasigna `_futureData`, así que
  // el FutureBuilder no vuelve a mostrar el spinner de carga inicial.
  Timer? _pollTimer;
  @override
  void initState() {
    super.initState();
    _futureData =showTeamAPI();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _silentRefresh());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _silentRefresh() async {
    await showTeamAPI();
    if (mounted) setState(() {});
  }

  List<dynamic>? teamsData;
  Future<void> showTeamAPI() async {
    dynamic storedValue = await secureStorage.readSecureData(key);

    const String apiUrl = '$kBaseUrl/team/showTeams';
    final response = await http.get(
        Uri.parse(apiUrl),
        headers: <String, String>{
          'Authorization' :storedValue,
        },);

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      teamsData = decoded['teams'];
      name = decoded['email'];
      // También se cachea en almacenamiento seguro (persiste entre
      // reinicios de la app), para que otras pantallas como el detalle de
      // equipo sepan "quién soy" sin depender de haber visitado antes esta
      // pestaña de Equipos.
      if (name != null && name!.isNotEmpty) {
        Session.cacheEmail(name!);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: const MyAppBar(),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
            child: SectionHeader(title: 'Equipos'),
          ),
          Expanded(
            child: FutureBuilder<void>(
              future: _futureData,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LoadingState();
                } else if (snapshot.hasError) {
                  return ErrorState(
                    message: 'No se pudieron cargar tus equipos.',
                    onRetry: () => setState(() => _futureData = showTeamAPI()),
                  );
                } else if (teamsData == null || teamsData!.isEmpty) {
                  return const EmptyState(
                    icon: Icons.groups_outlined,
                    title: 'Todavía no perteneces a ningún equipo',
                    message: 'Crea uno nuevo o únete con un código para empezar.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: teamsData!.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, index) {
                    final team = Map<String, dynamic>.from(teamsData![index]);
                    final domains = (team['domains'] as List?) ?? [];

                    final Set<String> members = {};
                    int pending = 0;
                    int completed = 0;
                    for (final domain in domains) {
                      for (final m in (domain['members'] as List? ?? [])) {
                        members.add(m.toString());
                      }
                      for (final t in (domain['tasks'] as List? ?? [])) {
                        if (t['completed'] == true) {
                          completed++;
                        } else {
                          pending++;
                        }
                      }
                    }

                    final String teamId = team['_id']?.toString() ?? '$index';
                    return TeamCard(
                      teamName: team['teamName']?.toString() ?? 'Sin nombre',
                      teamCode: team['teamCode']?.toString() ?? '',
                      memberCount: members.length,
                      pendingCount: pending,
                      completedCount: completed,
                      accentColor: TeamCard.colorForId(teamId),
                      onTap: () {
                        // Al volver de la pantalla del equipo (donde el
                        // líder pudo reasignar/reprogramar tareas desde
                        // "Gestionar tareas"), se refresca de inmediato en
                        // vez de esperar al próximo tick del polling.
                        Navigator.push(context,
                            MaterialPageRoute(builder: (context) => t_detail(team: teamsData![index])))
                            .then((_) => _silentRefresh());
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
