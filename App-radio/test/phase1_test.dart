// Pruebas de la lógica nueva de la Fase 1 que no toca red ni Navigator:
//  - la regla de "día laboral" que comparten todos los calendarios,
//  - el contador único de notificaciones sin leer.

import 'package:flutter_test/flutter_test.dart';

import 'package:doliv_social/core/notifications_controller.dart';
import 'package:doliv_social/models/calendar_event.dart';
import 'package:doliv_social/models/models.dart';
import 'package:doliv_social/shared/calendar/date_pickers.dart';

void main() {
  group('isWorkingDay (lunes a sábado)', () {
    test('el domingo NO es laboral', () {
      // 2026-09-06 es domingo.
      expect(isWorkingDay(DateTime(2026, 9, 6)), isFalse);
    });

    test('de lunes a sábado SÍ son laborales', () {
      for (var d = 7; d <= 12; d++) {
        // 2026-09-07 (lun) .. 2026-09-12 (sáb)
        expect(isWorkingDay(DateTime(2026, 9, d)), isTrue,
            reason: 'día $d');
      }
    });

    test('tableCalendarWorkingDay coincide con isWorkingDay', () {
      final sunday = DateTime(2026, 9, 6);
      final monday = DateTime(2026, 9, 7);
      expect(tableCalendarWorkingDay(sunday), isFalse);
      expect(tableCalendarWorkingDay(monday), isTrue);
    });

    test('el domingo es el único día de fin de semana configurado', () {
      expect(kWorkingWeekendDays, const [DateTime.sunday]);
    });
  });

  group('oneCalendarMonthMaxEnd (tope de un mes de calendario)', () {
    test('mismo día del mes siguiente cuando existe', () {
      expect(oneCalendarMonthMaxEnd(DateTime(2026, 1, 15)), DateTime(2026, 2, 15));
      expect(oneCalendarMonthMaxEnd(DateTime(2026, 2, 15)), DateTime(2026, 3, 15));
    });

    test('se ajusta al último día cuando el día no existe en el mes siguiente', () {
      // 2026 no es bisiesto: 31-ene -> 28-feb, 30-ene -> 28-feb.
      expect(oneCalendarMonthMaxEnd(DateTime(2026, 1, 31)), DateTime(2026, 2, 28));
      expect(oneCalendarMonthMaxEnd(DateTime(2026, 1, 30)), DateTime(2026, 2, 28));
    });

    test('bisiesto: 31-ene-2028 -> 29-feb-2028', () {
      expect(oneCalendarMonthMaxEnd(DateTime(2028, 1, 31)), DateTime(2028, 2, 29));
    });

    test('cruza el fin de año', () {
      expect(oneCalendarMonthMaxEnd(DateTime(2026, 12, 20)), DateTime(2027, 1, 20));
    });

    test('un rango de exactamente un mes es válido; un día más no', () {
      final start = DateTime(2026, 3, 10);
      final max = oneCalendarMonthMaxEnd(start); // 2026-04-10
      expect(DateTime(2026, 4, 10).isAfter(max), isFalse);
      expect(DateTime(2026, 4, 11).isAfter(max), isTrue);
    });
  });

  group('NotificationsController', () {
    setUp(() => NotificationsController.instance.clear());

    test('setUnread fija el valor y notifica', () {
      var notified = 0;
      void listener() => notified++;
      NotificationsController.instance.addListener(listener);
      addTearDown(() => NotificationsController.instance.removeListener(listener));

      NotificationsController.instance.setUnread(5);
      expect(NotificationsController.instance.unreadCount, 5);
      expect(notified, 1);

      // Mismo valor: no vuelve a notificar.
      NotificationsController.instance.setUnread(5);
      expect(notified, 1);
    });

    test('decrement no baja de cero', () {
      NotificationsController.instance.setUnread(1);
      NotificationsController.instance.decrement();
      NotificationsController.instance.decrement();
      expect(NotificationsController.instance.unreadCount, 0);
    });

    test('setUnreadFromList cuenta solo las que no tienen readAt', () {
      NotificationsController.instance.setUnreadFromList([
        {'readAt': null},
        {'readAt': '2026-09-01 10:00:00'},
        {'readAt': null},
      ]);
      expect(NotificationsController.instance.unreadCount, 2);
    });

    test('clear deja el contador en cero', () {
      NotificationsController.instance.setUnread(9);
      NotificationsController.instance.clear();
      expect(NotificationsController.instance.unreadCount, 0);
    });
  });

  group('UserProfile.emailVerified (verificación de correo)', () {
    Map<String, dynamic> base() => {
          'id': 'u1',
          'name': 'Ana',
          'email': 'ana@doliv.test',
          'role': 'employee',
        };

    test('emailVerified: true se lee como verificado', () {
      final p = UserProfile.fromJson(base()..['emailVerified'] = true);
      expect(p.emailVerified, isTrue);
    });

    test('emailVerified: false se lee como NO verificado', () {
      final p = UserProfile.fromJson(base()..['emailVerified'] = false);
      expect(p.emailVerified, isFalse);
    });

    test('sin el campo (backend viejo) se asume verificado', () {
      final p = UserProfile.fromJson(base());
      expect(p.emailVerified, isTrue);
    });
  });

  group('CalendarEvent (lugar + recordatorios)', () {
    Map<String, dynamic> base() => {
          'id': 'e1',
          'title': 'Junta',
          'date': '2026-09-20',
          'scope': 'general',
        };

    test('lee locationText y reminderOffsets cuando vienen', () {
      final e = CalendarEvent.fromJson(base()
        ..['locationText'] = 'Sala 3'
        ..['reminderOffsets'] = [5, 2]);
      expect(e.locationText, 'Sala 3');
      expect(e.reminderOffsets, [5, 2]);
    });

    test('sin reminderOffsets usa el conjunto por defecto 7/5/3/2', () {
      final e = CalendarEvent.fromJson(base());
      expect(e.reminderOffsets, [7, 5, 3, 2]);
      expect(e.locationText, isNull);
    });

    test('locationText vacío se normaliza a null', () {
      final e = CalendarEvent.fromJson(base()..['locationText'] = '');
      expect(e.locationText, isNull);
    });
  });
}
