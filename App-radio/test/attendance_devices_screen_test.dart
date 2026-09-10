import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doliv_social/models/attendance.dart';
import 'package:doliv_social/features/dashboard/director/attendance_devices_screen.dart';

void main() {
  testWidgets('DeviceRequestCard muestra empleado, modelo e intentos', (t) async {
    final row = const DeviceRequestRow(
      id: 1, employeeId: 'e1', employeeName: 'Ana Pérez', platform: 'android',
      model: 'Google Pixel 8', osVersion: 'Android 15', attempts: 3,
      firstSeen: '2026-09-09 08:00:00', lastSeen: '2026-09-09 09:00:00',
    );
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DeviceRequestCard(row: row, onApprove: () {}, onReject: () {}),
      ),
    ));
    expect(find.text('Ana Pérez'), findsOneWidget);
    expect(find.textContaining('Google Pixel 8'), findsOneWidget);
    expect(find.textContaining('3'), findsWidgets);
    expect(find.widgetWithText(TextButton, 'Aprobar'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Rechazar'), findsOneWidget);
  });

  testWidgets('TrustedDeviceCard muestra empleado, modelo y Restablecer', (t) async {
    final row = const TrustedDeviceRow(
      employeeId: 'e1', employeeName: 'Luis Gómez', model: 'Galaxy S23',
      osVersion: 'Android 14', platform: 'android',
      enrolledAt: '2026-09-01 08:00:00', via: 'director',
    );
    var reset = 0;
    await t.pumpWidget(MaterialApp(
      home: Scaffold(body: TrustedDeviceCard(row: row, onReset: () => reset++)),
    ));
    expect(find.text('Luis Gómez'), findsOneWidget);
    expect(find.textContaining('Galaxy S23'), findsOneWidget);
    expect(find.textContaining('aprobado por el director'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Restablecer'), findsOneWidget);
    await t.tap(find.widgetWithText(TextButton, 'Restablecer'));
    expect(reset, 1);
  });

  testWidgets('AnomalyTile muestra tipo legible y detalle', (t) async {
    final a = const DeviceAnomaly(
      type: 'frequent_device_change', employeeId: 'e1', employeeName: 'Ana',
      detail: '2 cambios de dispositivo en 30 días', at: null,
    );
    await t.pumpWidget(MaterialApp(home: Scaffold(body: AnomalyTile(anomaly: a))));
    expect(find.textContaining('Cambios frecuentes de dispositivo'), findsOneWidget);
    expect(find.textContaining('2 cambios de dispositivo'), findsOneWidget);
  });
}
