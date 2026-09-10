import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doliv_social/shared/attendance/attendance_device_banner.dart';
import 'package:doliv_social/models/attendance.dart';

void main() {
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
