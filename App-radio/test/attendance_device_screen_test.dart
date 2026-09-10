import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/shared/attendance/attendance_device_banner.dart';
import 'package:doliv_social/shared/attendance/attendance_time_cards.dart';
import 'package:doliv_social/models/attendance.dart';

AttendanceDay _dayWithEntrada() => AttendanceDay(
      workDate: DateTime(2026, 9, 9),
      state: AttendanceState.sinEntrada,
      stateLabel: 'Sin entrada',
      nextAction: AttendanceAction.entrada,
      entrada: null,
      inicioComida: null,
      finComida: null,
      salida: null,
      mealSkipped: false,
      mealMinutes: null,
      mealMinutesLabel: null,
      mealElapsedMinutes: null,
      workedMinutes: null,
      workedLabel: null,
      workedInProgress: false,
      isLate: false,
      lateMinutes: 0,
      toleranceMinutes: 15,
      mealLimitMinutes: null,
      mealExceeded: false,
      mealExcessMinutes: 0,
      schedule: null,
    );

void main() {
  group('AttendancePrimaryAction', () {
    // Con el dispositivo a la espera de autorización el botón debe quedar
    // deshabilitado: el backend rechazaría el fichaje con 409 UNKNOWN_DEVICE.
    Future<int> pumpAndTap(WidgetTester t, {required bool blocked}) async {
      var taps = 0;
      await t.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AttendancePrimaryAction(
            day: _dayWithEntrada(),
            submitting: false,
            blocked: blocked,
            onPerform: (_) => taps++,
          ),
        ),
      ));
      await t.tap(find.byType(AppButton), warnIfMissed: false);
      await t.pump();
      return taps;
    }

    testWidgets('blocked (dispositivo pendiente): el botón no ficha', (t) async {
      expect(await pumpAndTap(t, blocked: true), 0);
    });

    testWidgets('sin blocked: el botón ficha', (t) async {
      expect(await pumpAndTap(t, blocked: false), 1);
    });
  });

  group('AttendanceDeviceBanner', () {
    Future<void> pump(WidgetTester t, AttendanceDeviceState state) async {
      await t.pumpWidget(MaterialApp(
        home: Scaffold(body: AttendanceDeviceBanner(state: state, onRequest: () {})),
      ));
    }

    testWidgets('pending: mensaje de espera, sin botón', (t) async {
      await pump(t, AttendanceDeviceState.pending);
      expect(find.textContaining('Esperando'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Solicitar autorización del dispositivo'), findsNothing);
    });

    testWidgets('unknown: botón de solicitud', (t) async {
      await pump(t, AttendanceDeviceState.unknown);
      expect(find.widgetWithText(FilledButton, 'Solicitar autorización del dispositivo'), findsOneWidget);
    });

    testWidgets('none: aviso de que se vinculará', (t) async {
      await pump(t, AttendanceDeviceState.none);
      expect(find.textContaining('se vinculará'), findsOneWidget);
    });

    testWidgets('trusted: no renderiza nada', (t) async {
      await pump(t, AttendanceDeviceState.trusted);
      expect(find.byType(SizedBox), findsWidgets);
      expect(find.textContaining('Esperando'), findsNothing);
    });
  });
}
