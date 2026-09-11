import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  final _storage = const FlutterSecureStorage();

  Future<void> writeSecureData(String key, String? value) {
    return _storage.write(key: key, value: value);
  }

  Future<String?> readSecureData(String key) {
    return _storage.read(key: key);
  }

  Future<void> deleteSecureData(String key) {
    return _storage.delete(key: key);
  }
}