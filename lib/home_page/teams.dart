import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../design/design.dart';
import '../screens/login.dart';
import '../screens/teamDetail.dart';
import '../utils/api_config.dart';

class TeamPage extends StatefulWidget {
  const TeamPage({super.key});

  @override
  State<TeamPage> createState() => _TeamPageState();
}

class _TeamPageState extends State<TeamPage> {
  List<dynamic>? _teams;
  bool _loading = true;
  bool _hasError = false;
  // Refresca la lista sola cada pocos segundos (mismo patrón que el chat y
  // teamDetail): así, si el usuario acaba de crear un equipo, se agregó a
  // otro, o alguien más cambió el equipo, esta pantalla lo muestra sin
  // necesidad de deslizar para refrescar.
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadTeams();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _loadTeams(silent: true));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  /// `silent`: usado por el polling en segundo plano para no tapar la
  /// lista con el spinner de carga completa ni con el estado de error en
  /// cada intento fallido (un corte de red pasajero no debe "volver loca"
  /// la pantalla); el pull-to-refresh y la carga inicial sí lo muestran.
  Future<void> _loadTeams({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _hasError = false;
      });
    }
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
          _hasError = false;
        });
      } else if (!silent) {
        setState(() {
          _hasError = true;
          _loading = false;
        });
      }
    } catch (_) {
      if (!mounted || silent) return;
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
        message: 'Puedes crear uno nuevo o unirte con un código desde el inicio.',
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

/// Pantalla independiente que envuelve [TeamPage] con su propio AppBar (con
/// botón de "atrás"), para poder abrirla desde fuera de HomeNav — por
/// ejemplo desde el botón "Equipos" del resumen en Perfil — sin duplicar su
/// lógica de carga.
class TeamsFocusScreen extends StatelessWidget {
  const TeamsFocusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis equipos')),
      body: const TeamPage(),
    );
  }
}
