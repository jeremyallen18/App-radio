import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doliv_social/models/attendance.dart';
import 'package:doliv_social/features/dashboard/director/admin_schedule_screen.dart';
import 'package:doliv_social/shared/attendance/attendance_time_cards.dart';

void main() {
  group('EmployeeSchedule.lateToleranceMinutes', () {
    test('toma el valor del JSON', () {
      final s = EmployeeSchedule.fromJson({
        'entryTime': '09:00',
        'exitTime': '17:00',
        'mealTime': '14:00',
        'mealMaxMinutes': 60,
        'lateToleranceMinutes': 25,
      });
      expect(s.lateToleranceMinutes, 25);
    });

    test('default 15 cuando falta la clave', () {
      final s = EmployeeSchedule.fromJson({
        'entryTime': '09:00',
        'exitTime': '17:00',
        'mealTime': '14:00',
        'mealMaxMinutes': 60,
      });
      expect(s.lateToleranceMinutes, 15);
    });
  });

  test('AttendanceDay.toleranceMinutes es null-safe', () {
    final d = AttendanceDay.fromJson({'state': 'sin_entrada'});
    expect(d.toleranceMinutes, isNull);
    final d2 = AttendanceDay.fromJson({'state': 'en_jornada', 'toleranceMinutes': 15});
    expect(d2.toleranceMinutes, 15);
  });

  group('editor de horario — campo de tolerancia', () {
    EmployeeScheduleRow rowWithTolerance(int tol) => EmployeeScheduleRow.fromJson({
          'employeeId': 'e1',
          'name': 'Ana Pérez',
          'email': 'ana@example.com',
          'position': 'Analista',
          'schedule': {
            'entryTime': '09:00',
            'exitTime': '17:00',
            'mealTime': '14:00',
            'mealMaxMinutes': 60,
            'lateToleranceMinutes': tol,
          },
        });

    Future<void> pumpEditor(WidgetTester tester, EmployeeScheduleRow row) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ScheduleEditor(row: row),
            ),
          ),
        ),
      );
    }

    const rangeError = 'La tolerancia de retardo debe estar entre 0 y 60 minutos.';

    testWidgets('precarga el valor guardado en el campo', (tester) async {
      await pumpEditor(tester, rowWithTolerance(20));
      expect(find.widgetWithText(TextField, '20'), findsOneWidget);
    });

    testWidgets('rechaza -1 con el mensaje de rango en español', (tester) async {
      await pumpEditor(tester, rowWithTolerance(20));
      await tester.enterText(
          find.widgetWithText(TextField, '20'), '-1');
      await tester.tap(find.text('GUARDAR CAMBIOS'));
      await tester.pump();
      expect(find.text(rangeError), findsOneWidget);
    });

    testWidgets('rechaza 61 con el mensaje de rango en español', (tester) async {
      await pumpEditor(tester, rowWithTolerance(20));
      await tester.enterText(
          find.widgetWithText(TextField, '20'), '61');
      await tester.tap(find.text('GUARDAR CAMBIOS'));
      await tester.pump();
      expect(find.text(rangeError), findsOneWidget);
    });

    testWidgets('acepta 0 sin mostrar el error de rango', (tester) async {
      await pumpEditor(tester, rowWithTolerance(20));
      await tester.enterText(
          find.widgetWithText(TextField, '20'), '0');
      await tester.tap(find.text('GUARDAR CAMBIOS'));
      await tester.pump();
      expect(find.text(rangeError), findsNothing);
    });

    testWidgets('acepta 60 sin mostrar el error de rango', (tester) async {
      await pumpEditor(tester, rowWithTolerance(20));
      await tester.enterText(
          find.widgetWithText(TextField, '20'), '60');
      await tester.tap(find.text('GUARDAR CAMBIOS'));
      await tester.pump();
      expect(find.text(rangeError), findsNothing);
    });
  });

  group('leyenda de disponibilidad', () {
    // La leyenda solo aparece mientras la ventana sigue en el futuro; una vez
    // abierta desaparece para no leerse como advertencia. Se prueba la lógica
    // pura (`attendanceAvailabilityHint`) con un "ahora" fijo, así el resultado
    // no depende del reloj de pared en el que corran las pruebas.
    EmployeeSchedule schedule({
      String entryTime = '09:00',
      String mealTime = '14:00',
      String exitTime = '17:00',
    }) =>
        EmployeeSchedule.fromJson({
          'entryTime': entryTime,
          'exitTime': exitTime,
          'mealTime': mealTime,
          'mealMaxMinutes': 60,
          'lateToleranceMinutes': 15,
        });

    // 10:00 => 600 minutos desde medianoche.
    const now10h = 10 * 60;

    test('entrada: ventana futura muestra "desde las 08:30"', () {
      final hint = attendanceAvailabilityHint(
          AttendanceAction.entrada, schedule(entryTime: '09:00'),
          nowMinutes: 8 * 60); // 08:00 < 08:30
      expect(hint, contains('08:30'));
    });

    test('entrada: ventana ya abierta => sin leyenda', () {
      final hint = attendanceAvailabilityHint(
          AttendanceAction.entrada, schedule(entryTime: '09:00'),
          nowMinutes: now10h); // 10:00, ya pasó 08:30
      expect(hint, isNull);
    });

    test('entrada: "disponible desde" envuelve al día anterior => sin leyenda',
        () {
      final hint = attendanceAvailabilityHint(
          AttendanceAction.entrada, schedule(entryTime: '00:01'),
          nowMinutes: now10h);
      expect(hint, isNull);
    });

    test('inicio de comida: ventana futura muestra "desde las 14:00"', () {
      final hint = attendanceAvailabilityHint(
          AttendanceAction.inicioComida, schedule(mealTime: '14:00'),
          nowMinutes: now10h);
      expect(hint, contains('14:00'));
    });

    test('inicio de comida: ventana ya abierta => sin leyenda', () {
      final hint = attendanceAvailabilityHint(
          AttendanceAction.inicioComida, schedule(mealTime: '14:00'),
          nowMinutes: 15 * 60);
      expect(hint, isNull);
    });

    test('salida: null cuando no hay horario', () {
      expect(
        attendanceAvailabilityHint(AttendanceAction.salida, null,
            nowMinutes: now10h),
        isNull,
      );
    });

    test('salida: formato de hora inválido => sin leyenda', () {
      final hint = attendanceAvailabilityHint(
          AttendanceAction.salida, schedule(exitTime: 'xx:yy'),
          nowMinutes: now10h);
      expect(hint, isNull);
    });
  });
}
