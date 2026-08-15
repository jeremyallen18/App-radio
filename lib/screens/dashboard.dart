
import "dart:convert";

import 'teamDetail.dart';
import "package:flutter/material.dart";
import 'package:http/http.dart' as http;
import "login.dart";
import 'package:doliv_social/models/appbar.dart';
import 'package:doliv_social/screens/chat.dart';
import '../design/design.dart';
import '../utils/api_config.dart';

class dashb_mem extends StatefulWidget {
  const dashb_mem({super.key});
  @override
  State<dashb_mem> createState() => dashb_memState();
}
String? name;
class dashb_memState extends State<dashb_mem> {
  Future<void>? _futureData;
  @override
  void initState() {
    super.initState();
    _futureData =showTeamAPI();
  }
  List<dynamic>? teamsData;
  List<String>? teamNames;
  Future<void> showTeamAPI() async {
    dynamic storedValue = await secureStorage.readSecureData(key);

    const String apiUrl = '$kBaseUrl/team/showTeams';
    final response = await http.get(
        Uri.parse(apiUrl),
        headers: <String, String>{
          'Authorization' :storedValue,

        },);

    if (response.statusCode == 200) {
      teamsData = jsonDecode(response.body)['teams'];
      name = jsonDecode(response.body)['email'];
      teamNames = teamsData!.map<String>((team) => team['teamName'].toString()).toList();
      name=jsonDecode(response.body)['email'];
    } else {
      print(' ${response.statusCode}');
      print('Error Message: ${response.body}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      floatingActionButton: FloatingActionButton(
        onPressed: (){
           Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(name!)));
        },
        child: const Icon(Icons.chat),
      ),
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
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: ResponsiveCardGrid(
                    children: [
                      for (int index = 0; index < teamsData!.length; index++)
                        Builder(builder: (context) {
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
                              Navigator.push(context,
                                  MaterialPageRoute(builder: (context) => t_detail(team: teamsData![index])));
                            },
                          );
                        }),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
