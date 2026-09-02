import 'dart:convert';
import 'package:brl_task4/create&join-Team/create-team.dart';
import 'package:brl_task4/screens/login.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../design/design.dart';
import '../screens/teamDetail.dart';
import '../utils/api_config.dart';

class TeamDetailsScreen extends StatelessWidget {
  final List<Domain> selectedDomains;
  final String teamname;
  final String teamId;

  const TeamDetailsScreen(this.teamname, this.selectedDomains, this.teamId, {super.key});

  static const List<IconData> _domainIcons = [
    Icons.code_rounded,
    Icons.monitor,
    Icons.model_training_rounded,
    Icons.developer_board_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(title: Text(teamname)),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader(title: 'Invita miembros por área'),
          Text(
            'Toca un área para enviar invitaciones por correo. Puedes hacerlo ahora o más tarde desde el equipo.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: selectedDomains.isEmpty
                ? const EmptyState(
                    icon: Icons.domain_disabled_outlined,
                    title: 'Este equipo no tiene áreas',
                    message: 'Vuelve a crear el equipo y selecciona al menos un área.',
                  )
                : ListView.separated(
                    itemCount: selectedDomains.length,
                    separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final domain = selectedDomains[index];
                      final icon = _domainIcons[index % _domainIcons.length];
                      return AppCard(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => InviteMembersScreen(domain, teamId: teamId),
                            ),
                          );
                        },
                        child: Row(
                          children: [
                            Icon(icon, color: AppColors.accent),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Text(
                                domain.name,
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Icon(Icons.chevron_right, color: AppColors.textMuted),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

class InviteMembersScreen extends StatefulWidget {
  final Domain domain;
  final String teamId;

  const InviteMembersScreen(this.domain, {super.key, required this.teamId});

  @override
  State<InviteMembersScreen> createState() => _InviteMembersScreenState();
}

class _InviteMembersScreenState extends State<InviteMembersScreen> {
  final TextEditingController emailController = TextEditingController();
  bool _sending = false;
  // Se activa apenas se envía una invitación con éxito, para mostrar el
  // botón "Ver equipo" que lleva directo al detalle del equipo sin tener
  // que volver atrás por Crear equipo -> Áreas -> Invitar.
  bool _invitationSent = false;
  bool _loadingTeam = false;

  /// Trae el equipo recién creado con toda la info que necesita `t_detail`
  /// (líder, código, miembros, áreas) y navega directo ahí, eliminando del
  /// stack las pantallas intermedias del flujo de creación/invitación.
  Future<void> _goToTeam() async {
    setState(() => _loadingTeam = true);
    try {
      final token = await secureStorage.readSecureData(key);
      final response = await http.get(
        Uri.parse('$kBaseUrl/team/showTeams'),
        headers: <String, String>{'Authorization': token ?? ''},
      );
      if (!mounted) return;

      if (response.statusCode == 200) {
        final List<dynamic> teams = jsonDecode(response.body)['teams'] ?? [];
        Map<String, dynamic>? team;
        for (final t in teams) {
          final candidate = Map<String, dynamic>.from(t as Map);
          if (candidate['_id']?.toString() == widget.teamId) {
            team = candidate;
            break;
          }
        }

        if (team != null) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => t_detail(team: team)),
            (route) => route.isFirst,
          );
          return;
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el equipo')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error de red al abrir el equipo')),
      );
    } finally {
      if (mounted) setState(() => _loadingTeam = false);
    }
  }

  Future<void> _sendInvitation() async {
    final email = emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un correo')),
      );
      return;
    }

    setState(() => _sending = true);
    dynamic storedValue = await secureStorage.readSecureData(key);
    var headers = <String, String>{
      'Authorization': storedValue,
      'Content-Type': 'application/json',
    };

    var request = http.Request(
      'POST',
      Uri.parse('$kBaseUrl/team/sendTeamcode/${widget.teamId}/${widget.domain.name}'),
    );

    request.body = json.encode({
      "recipients": [email],
    });

    request.headers.addAll(headers);

    try {
      http.StreamedResponse response = await request.send();
      if (!mounted) return;

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData =
            jsonDecode(await response.stream.bytesToString());
        if (!mounted) return;
        if (responseData['success'] == true) {
          emailController.clear();
          setState(() => _invitationSent = true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(responseData['message']?.toString() ?? 'Invitación enviada'),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(responseData['message']?.toString() ?? 'No se pudo enviar la invitación'),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo enviar la invitación (${response.statusCode})')),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error de red al enviar la invitación')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(title: Text('Invitar a ${widget.domain.name}')),
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.lg),
          Text(
            'La persona invitada recibirá el código para unirse al equipo en esta área.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            controller: emailController,
            prefixIcon: Icon(Icons.mail_outline, color: AppColors.textMuted),
            hintText: 'Correo para invitar',
            textInputType: TextInputType.emailAddress,
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: _sending ? 'Enviando…' : 'Enviar invitación',
            loading: _sending,
            onPressed: _sending ? null : _sendInvitation,
          ),
          if (_invitationSent) ...[
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 50,
              child: OutlinedButton.icon(
                onPressed: _loadingTeam ? null : _goToTeam,
                icon: _loadingTeam
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.groups_outlined),
                label: Text(_loadingTeam ? 'Abriendo…' : 'Ver equipo'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accentStrong,
                  side: BorderSide(color: AppColors.surfaceBorder),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
