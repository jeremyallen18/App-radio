import 'package:flutter/material.dart';

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/shared/chat/chat.dart';
import 'package:doliv_social/shared/leave/leave.dart';
import 'package:doliv_social/shared/resources/resources.dart';
import 'package:doliv_social/shared/teams/l_resign.dart';
import 'package:doliv_social/shared/teams/m_resign.dart';

String _shortName(String value) =>
    value.contains('@') ? value.substring(0, value.indexOf('@')) : value;

/// Tarjeta de un área (domain) del equipo: miembros, contadores de tareas y la
/// lista de tareas con su estado. Para el líder, con tareas pendientes, muestra
/// el botón "Completar tarea" ([onCompleteTask]).
class TeamDomainCard extends StatelessWidget {
  const TeamDomainCard({
    super.key,
    required this.domain,
    required this.isLeader,
    required this.onCompleteTask,
  });

  final dynamic domain;
  final bool isLeader;
  final VoidCallback onCompleteTask;

  @override
  Widget build(BuildContext context) {
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
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (members.isEmpty)
            Text("Sin miembros todavía",
                style: TextStyle(color: AppColors.textMuted, fontSize: 13))
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: members.map((m) {
                final s = m.toString();
                return Chip(
                  backgroundColor: AppColors.surface,
                  visualDensity: VisualDensity.compact,
                  avatar:
                      Icon(Icons.person, size: 14, color: AppColors.textMuted),
                  label: Text(
                    _shortName(s),
                    style:
                        TextStyle(color: AppColors.textPrimary, fontSize: 12),
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 14),
          Row(
            children: [
              _statusPill(Icons.pending_actions, "$pendingCount pendientes",
                  AppColors.error),
              const SizedBox(width: 8),
              _statusPill(
                  Icons.check_circle, "$doneCount hechas", AppColors.success),
            ],
          ),
          const SizedBox(height: 10),
          if (tasks.isEmpty)
            Text("Sin tareas en esta área todavía",
                style: TextStyle(color: AppColors.textMuted, fontSize: 13))
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
                        done
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
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
                                color: done
                                    ? AppColors.textMuted
                                    : AppColors.textPrimary,
                                fontSize: 14,
                                decoration:
                                    done ? TextDecoration.lineThrough : null,
                              ),
                            ),
                            Text(
                              "Para: ${_shortName(assignedTo)}  ·  Vence: ${t['deadline']}",
                              style: TextStyle(
                                  color: AppColors.textMuted, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          if (isLeader && pendingCount > 0) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onCompleteTask,
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
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Tira de acciones del equipo: un set para el líder (chat, recursos, gestionar
/// miembros, eliminar) y otro para el resto (salir, renunciar, chat, recursos).
class TeamActionsCard extends StatelessWidget {
  const TeamActionsCard({
    super.key,
    required this.isLeader,
    required this.teamId,
    required this.teamId2,
    required this.leaderEmail,
    required this.onDeleteTeam,
  });

  final bool isLeader;
  final String? teamId;
  final String teamId2;
  final String? leaderEmail;
  final VoidCallback onDeleteTeam;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.textPrimary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: !isLeader
          ? Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                _actionButton("Salir", Icons.logout, () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ApplyLeave(
                        teamid: teamId2,
                      ),
                    ),
                  );
                }),
                _actionButton("Renunciar", Icons.person_remove_outlined, () {
                  Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              Mresign(teamId: teamId, emailId: leaderEmail)));
                }),
                _actionButton("Chat", Icons.chat_bubble_outline, () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => ChatScreen(
                              peerEmail: leaderEmail!,
                              peerName: "Lider del equipo")));
                }),
                _actionButton("Recursos", Icons.folder_outlined, () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => ResourceM(teamId!)));
                }),
              ],
            )
          : Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                _actionButton("Chat", Icons.chat_bubble_outline, () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => ChatScreen(
                              peerEmail: leaderEmail!,
                              peerName: "Lider del equipo")));
                }),
                _actionButton("Recursos", Icons.folder_outlined, () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => ResourceM(teamId!)));
                }),
                _actionButton(
                    "Gestionar miembros", Icons.manage_accounts_outlined, () {
                  Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (context) => Resign(teamId: teamId)));
                }),
                _actionButton(
                    "Eliminar equipo", Icons.delete_outline, onDeleteTeam,
                    danger: true),
              ],
            ),
    );
  }

  Widget _actionButton(String label, IconData icon, VoidCallback onTap,
      {bool danger = false}) {
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

/// Hoja inferior para elegir cuál de las tareas pendientes de un área marcar
/// como completada. Llama a [onSelected] con el índice (en `domain['tasks']`)
/// de la tarea elegida, después de cerrarse.
class TeamTaskPickerSheet extends StatelessWidget {
  const TeamTaskPickerSheet({
    super.key,
    required this.domain,
    required this.onSelected,
  });

  final dynamic domain;
  final void Function(int taskIndex) onSelected;

  @override
  Widget build(BuildContext context) {
    final List tasks = (domain['tasks'] as List?) ?? [];
    final pending = <int>[
      for (int i = 0; i < tasks.length; i++)
        if (tasks[i]['completed'] == false) i,
    ];

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
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700),
            ),
            Text(
              "Área: ${domain['name']}",
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 12),
            if (pending.isEmpty)
              Padding(
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
                  separatorBuilder: (_, __) =>
                      Divider(color: AppColors.surfaceBorder, height: 1),
                  itemBuilder: (context, i) {
                    final taskIndex = pending[i];
                    final t = tasks[taskIndex];
                    final assignedTo = t['assignedTo'] as String;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.radio_button_unchecked,
                          color: AppColors.error),
                      title: Text(
                        t['description'] ?? '',
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        "Para: ${_shortName(assignedTo)}  ·  Vence: ${t['deadline']}",
                        style:
                            TextStyle(color: AppColors.textMuted, fontSize: 12),
                      ),
                      trailing:
                          Icon(Icons.chevron_right, color: AppColors.textMuted),
                      onTap: () {
                        Navigator.pop(context);
                        onSelected(taskIndex);
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
