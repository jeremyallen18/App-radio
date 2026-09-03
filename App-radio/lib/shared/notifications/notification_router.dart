import 'package:flutter/material.dart';

import 'package:doliv_social/features/dashboard/director/admin_absence_screen.dart';
import 'package:doliv_social/shared/calendar/calendar_screen.dart';
import 'package:doliv_social/shared/chat/chat.dart';
import 'package:doliv_social/shared/chat/chatHistory.dart';
import 'package:doliv_social/shared/attendance/attendance_history_screen.dart';
import 'package:doliv_social/shared/home/teams.dart';
import 'package:doliv_social/shared/leave/absence_justification_screen.dart';
import 'package:doliv_social/shared/leave/my_leave_screen.dart';

/// Traduce una notificación en la pantalla a la que hay que ir al tocarla.
///
/// El destino se decide por `type` (categoría) y, cuando existe, por
/// `entityType`/`entityId` (destino estructurado — ver migración 020). Si el
/// tipo no tiene un destino claro, no navega (la notificación solo se marca
/// como leída). Nunca lanza: si algo falla, muestra un aviso y no rompe la
/// pantalla de notificaciones.
class NotificationRouter {
  const NotificationRouter._();

  /// Devuelve `true` si abrió una pantalla.
  static Future<bool> open(BuildContext context, Map notification) async {
    final String type = notification['type']?.toString() ?? '';
    final String? entityType = notification['entityType']?.toString();
    final String? entityId = (notification['entityId']?.toString().isNotEmpty ?? false)
        ? notification['entityId'].toString()
        : null;

    Widget? target;
    try {
      switch (type) {
        case 'chat':
          if (entityType == 'user' && entityId != null && entityId.contains('@')) {
            target = ChatScreen(peerEmail: entityId);
          } else {
            target = const ChatScreenfetch();
          }
          break;

        case 'leave_approved':
        case 'leave_rejected':
        case 'leave_cancelled':
          target = const MyLeaveScreen();
          break;

        // Justificación de faltas: al trabajador (resultado de su
        // justificación) y al director (una nueva por revisar).
        case 'absence_approved':
        case 'absence_rejected':
          target = const AbsenceJustificationScreen();
          break;
        case 'absence_justification':
          target = const AdminAbsenceScreen();
          break;

        // Las tareas con fecha límite y los eventos se ven en el calendario.
        case 'dept_task':
        case 'task_assigned':
        case 'event_created':
        case 'event_reminder':
          target = const CalendarScreen();
          break;

        case 'attendance_correction':
          target = const AttendanceHistoryScreen();
          break;

        case 'member_removed':
        case 'team_deleted':
        case 'leader_assigned':
          target = const TeamPage();
          break;

        // internal_announcement*, department_*, etc.: sin pantalla propia a la
        // que llevar; se quedan solo marcadas como leídas.
        default:
          return false;
      }

      if (!context.mounted) return false;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => target!),
      );
      return true;
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(
            content: Text('Ese contenido ya no está disponible.'),
          ));
      }
      return false;
    }
  }
}
