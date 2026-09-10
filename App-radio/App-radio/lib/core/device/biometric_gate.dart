import 'package:flutter/services.dart' show PlatformException;
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:local_auth/local_auth.dart';

enum BiometricOutcome { ok, skipped, failed, noLock }

/// Resultado de la verificación del SO antes de fichar. `type` es una pista
/// gruesa del factor disponible ('fingerprint' | 'face' | 'device_credential').
class BiometricResult {
  const BiometricResult(this.outcome, this.type);

  final BiometricOutcome outcome;
  final String? type;

  bool get passed =>
      outcome == BiometricOutcome.ok || outcome == BiometricOutcome.skipped;

  String get apiValue => switch (outcome) {
        BiometricOutcome.ok => 'ok',
        BiometricOutcome.skipped => 'skipped',
        _ => 'failed',
      };
}

/// Envuelve `local_auth`. Acepta PIN/patrón como respaldo; sin ningún bloqueo
/// de pantalla devuelve `noLock` para que asistencia bloquee el fichaje.
class BiometricGate {
  BiometricGate([LocalAuthentication? auth])
      : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  Future<BiometricResult> verify(String reason) async {
    try {
      if (!await _auth.isDeviceSupported()) {
        return const BiometricResult(BiometricOutcome.noLock, null);
      }
      final available = await _auth.getAvailableBiometrics();
      final ok = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
      if (!ok) return const BiometricResult(BiometricOutcome.failed, null);

      if (available.contains(BiometricType.face)) {
        return const BiometricResult(BiometricOutcome.ok, 'face');
      }
      if (available.contains(BiometricType.fingerprint) ||
          available.contains(BiometricType.strong) ||
          available.contains(BiometricType.weak)) {
        return const BiometricResult(BiometricOutcome.ok, 'fingerprint');
      }
      return const BiometricResult(BiometricOutcome.skipped, 'device_credential');
    } on PlatformException catch (e) {
      if (e.code == auth_error.notAvailable ||
          e.code == auth_error.notEnrolled ||
          e.code == auth_error.passcodeNotSet) {
        return const BiometricResult(BiometricOutcome.noLock, null);
      }
      return const BiometricResult(BiometricOutcome.failed, null);
    }
  }
}
