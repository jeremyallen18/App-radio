import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../design/design.dart';
import '../screens/login.dart';
import '../screens/teamDetail.dart';
import '../utils/api_config.dart';
import '../Utils/Routes.dart';

class TeamPage extends StatefulWidget {
  const TeamPage({super.key});

  @override
  State<TeamPage> createState() => _TeamPageState();
}

class _TeamPageState extends State<TeamPage> {
  List<dynamic>? _teams;
  bool _loading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadTeams();
  }

  Future<void> _loadTeams() async {
    setState(() {
      _loading = true;
      _hasError = false;
    });
    final token = await secureStorage.readSecureData(key);
    try {
      final response = await http.get(
        Uri.parse('$kBaseUrl/team/showTeams'),
        headers: <String, String>{'Authorization': token ?? ''},
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        setState(() {
          _teams = jsonDecode(response.body)['teams'] ?? [];
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              QuickActionChip(
                icon: Icons.add_circle_outline,
                label: 'Crear equipo',
                onTap: () => Navigator.pushNamed(context, MyRoutes.CreateTeamScreen),
              ),
              QuickActionChip(
                icon: Icons.group_add_outlined,
                label: 'Unirse a un equipo',
                onTap: () => Navigator.pushNamed(context, MyRoutes.jointeamRoutes),
              ),
            ],
          ),
        ),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) return const LoadingState();
    if (_hasError) return ErrorState(onRetry: _loadTeams);
    final teams = _teams ?? [];
    if (teams.isEmpty) {
      return const EmptyState(
        icon: Icons.groups_outlined,
        title: 'Todavía no perteneces a ningún equipo',
        message: 'Crea uno nuevo o únete con un código para empezar.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTeams,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: teams.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) {
          final team = Map<String, dynamic>.from(teams[index]);
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
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => t_detail(team: team)),
              );
            },
          );
        },
      ),
    );
  }
}
