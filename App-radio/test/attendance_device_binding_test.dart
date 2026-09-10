import 'package:flutter_test/flutter_test.dart';
import 'package:doliv_social/core/device/device_identity.dart';
import 'package:doliv_social/core/device/biometric_gate.dart';
import 'package:doliv_social/models/attendance.dart';

void main() {
  group('DeviceIdentity.toBody', () {
    test('incluye deviceKey solo si no es nulo', () {
      final withKey = DeviceIdentity.forTest(key: 'abc', uuid: 'u1', platform: 'android');
      expect(withKey.toBody()['deviceKey'], 'abc');
      expect(withKey.toBody()['deviceUuid'], 'u1');
      expect(withKey.toBody()['platform'], 'android');

      final noKey = DeviceIdentity.forTest(key: null, uuid: 'u2', platform: 'ios');
      expect(noKey.toBody().containsKey('deviceKey'), false);
      expect(noKey.toBody()['deviceUuid'], 'u2');
    });

    test('omite metadatos nulos', () {
      final d = DeviceIdentity.forTest(key: 'k', uuid: 'u', platform: 'android');
      final body = d.toBody();
      expect(body.containsKey('model'), false);
      expect(body.containsKey('osVersion'), false);
    });
  });

  group('BiometricResult', () {
    test('apiValue y passed según outcome', () {
      expect(const BiometricResult(BiometricOutcome.ok, 'face').apiValue, 'ok');
      expect(const BiometricResult(BiometricOutcome.ok, 'face').passed, true);
      expect(const BiometricResult(BiometricOutcome.skipped, 'device_credential').apiValue, 'skipped');
      expect(const BiometricResult(BiometricOutcome.skipped, null).passed, true);
      expect(const BiometricResult(BiometricOutcome.failed, null).apiValue, 'failed');
      expect(const BiometricResult(BiometricOutcome.failed, null).passed, false);
      expect(const BiometricResult(BiometricOutcome.noLock, null).passed, false);
    });
  });

  group('modelos de dispositivo', () {
    test('AttendanceDeviceStatus.fromJson', () {
      final s = AttendanceDeviceStatus.fromJson({
        'state': 'pending',
        'device': {'model': 'Pixel 7', 'osVersion': 'Android 14', 'via': 'first_use'},
      });
      expect(s.state, AttendanceDeviceState.pending);
      expect(s.model, 'Pixel 7');
      expect(s.via, 'first_use');
    });

    test('state desconocido cae a unknown', () {
      expect(AttendanceDeviceStatus.fromJson({'state': 'algo-raro'}).state,
          AttendanceDeviceState.unknown);
    });

    test('DeviceRequestRow.fromJson', () {
      final r = DeviceRequestRow.fromJson({
        'id': 4,
        'employee': {'id': 'e1', 'name': 'Ana'},
        'platform': 'android',
        'model': 'Pixel 8',
        'osVersion': 'Android 15',
        'attempts': 3,
        'firstSeen': '2026-09-09 08:00:00',
        'lastSeen': '2026-09-09 09:00:00',
      });
      expect(r.id, 4);
      expect(r.employeeName, 'Ana');
      expect(r.attempts, 3);
    });

    test('DeviceAnomaly.fromJson', () {
      final a = DeviceAnomaly.fromJson({
        'type': 'frequent_device_change',
        'employeeId': 'e1',
        'employeeName': 'Ana',
        'detail': '2 cambios en 30 días',
        'at': null,
      });
      expect(a.type, 'frequent_device_change');
      expect(a.at, isNull);
    });
  });
}
