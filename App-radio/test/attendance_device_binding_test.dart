import 'package:flutter_test/flutter_test.dart';
import 'package:doliv_social/core/device/device_identity.dart';

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
}
