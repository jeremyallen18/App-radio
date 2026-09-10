import 'dart:io' show Platform;
import 'dart:math';

import 'package:android_id/android_id.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:doliv_social/core/session_keys.dart' show secureStorage;

/// Identidad estable del dispositivo para vincular el fichaje a una cuenta.
/// `key` = `ANDROID_ID` / `identifierForVendor`; si el SO no lo da, el backend
/// empareja por `uuid` (aleatorio, generado una vez y guardado en el almacén
/// seguro).
class DeviceIdentity {
  const DeviceIdentity({
    required this.key,
    required this.uuid,
    required this.platform,
    this.model,
    this.osVersion,
    this.appVersion,
  });

  final String? key;
  final String uuid;
  final String platform; // 'android' | 'ios'
  final String? model;
  final String? osVersion;
  final String? appVersion;

  static const _uuidStorageKey = 'att_device_uuid';

  /// Constructor sin platform channels, para pruebas.
  static DeviceIdentity forTest({
    required String? key,
    required String uuid,
    required String platform,
    String? model,
    String? osVersion,
    String? appVersion,
  }) =>
      DeviceIdentity(
        key: key,
        uuid: uuid,
        platform: platform,
        model: model,
        osVersion: osVersion,
        appVersion: appVersion,
      );

  static Future<DeviceIdentity> current() async {
    final uuid = await _ensureUuid();
    final info = DeviceInfoPlugin();
    String? appVersion;
    try {
      final pkg = await PackageInfo.fromPlatform();
      appVersion = '${pkg.version}+${pkg.buildNumber}';
    } catch (_) {
      appVersion = null;
    }

    if (Platform.isIOS) {
      final ios = await info.iosInfo;
      return DeviceIdentity(
        key: ios.identifierForVendor,
        uuid: uuid,
        platform: 'ios',
        model: ios.utsname.machine,
        osVersion: '${ios.systemName} ${ios.systemVersion}',
        appVersion: appVersion,
      );
    }

    final android = await info.androidInfo;
    String? androidId;
    try {
      androidId = await const AndroidId().getId();
    } catch (_) {
      androidId = null;
    }
    return DeviceIdentity(
      key: androidId,
      uuid: uuid,
      platform: 'android',
      model: '${android.manufacturer} ${android.model}',
      osVersion: 'Android ${android.version.release} (SDK ${android.version.sdkInt})',
      appVersion: appVersion,
    );
  }

  static Future<String> _ensureUuid() async {
    final existing = await secureStorage.readSecureData(_uuidStorageKey);
    if (existing is String && existing.isNotEmpty) return existing;
    final generated = _randomUuidV4();
    await secureStorage.writeSecureData(_uuidStorageKey, generated);
    return generated;
  }

  static String _randomUuidV4() {
    final r = Random.secure();
    final b = List<int>.generate(16, (_) => r.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    String h(int i) => b[i].toRadixString(16).padLeft(2, '0');
    return '${h(0)}${h(1)}${h(2)}${h(3)}-${h(4)}${h(5)}-${h(6)}${h(7)}-'
        '${h(8)}${h(9)}-${h(10)}${h(11)}${h(12)}${h(13)}${h(14)}${h(15)}';
  }

  Map<String, String> toBody() => {
        if (key != null && key!.isNotEmpty) 'deviceKey': key!,
        'deviceUuid': uuid,
        'platform': platform,
        if (model != null && model!.isNotEmpty) 'model': model!,
        if (osVersion != null && osVersion!.isNotEmpty) 'osVersion': osVersion!,
        if (appVersion != null && appVersion!.isNotEmpty) 'appVersion': appVersion!,
      };
}
