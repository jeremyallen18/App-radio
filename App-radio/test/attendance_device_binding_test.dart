import 'package:flutter_test/flutter_test.dart';
import 'package:doliv_social/core/device/device_identity.dart';
import 'package:doliv_social/core/device/biometric_gate.dart';

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
}
