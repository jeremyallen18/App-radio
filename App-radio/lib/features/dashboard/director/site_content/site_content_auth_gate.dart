import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:local_auth/local_auth.dart';

import 'package:doliv_social/design/design.dart';

/// Exige la huella, el rostro o el PIN/patrón/contraseña del dispositivo
/// antes de mostrar [child]. Protege "Contenido del sitio web" porque
/// publica cambios de inmediato en radiodoliv.com — solo debería poder
/// tocarlo quien tiene el celular desbloqueado en la mano, no cualquiera
/// que encuentre la app con la sesión ya abierta.
class SiteContentAuthGate extends StatefulWidget {
  const SiteContentAuthGate({super.key, required this.child});

  final Widget child;

  @override
  State<SiteContentAuthGate> createState() => _SiteContentAuthGateState();
}

class _SiteContentAuthGateState extends State<SiteContentAuthGate> {
  final _auth = LocalAuthentication();
  bool _authenticated = false;
  bool _checking = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _authenticate();
  }

  Future<void> _authenticate() async {
    setState(() {
      _checking = true;
      _error = null;
    });

    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) {
        // Sin bloqueo de dispositivo configurado (p. ej. un emulador sin
        // PIN/huella): no hay nada que verificar, así que se deja pasar en
        // vez de bloquear el acceso sin salida.
        if (!mounted) return;
        setState(() {
          _authenticated = true;
          _checking = false;
        });
        return;
      }

      final ok = await _auth.authenticate(
        localizedReason: 'Confirma tu identidad para editar el contenido del sitio web',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
      if (!mounted) return;
      setState(() {
        _authenticated = ok;
        _checking = false;
        _error = ok ? null : 'No se pudo verificar tu identidad.';
      });
    } on PlatformException catch (e) {
      if (!mounted) return;
      final noLock = e.code == auth_error.notAvailable || e.code == auth_error.notEnrolled;
      setState(() {
        _authenticated = false;
        _checking = false;
        _error = noLock
            ? 'Configura una huella, rostro o PIN en tu dispositivo para continuar.'
            : 'No se pudo verificar tu identidad.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_authenticated) return widget.child;

    return AppScaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.fingerprint, color: AppColors.accent, size: 36),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'Verificación requerida',
              style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 20),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              _error ?? 'Usa tu huella, rostro o el bloqueo del dispositivo para continuar.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: AppSpacing.xl),
            if (_checking)
              const CircularProgressIndicator(color: AppColors.accent)
            else
              AppButton(label: 'Reintentar', onPressed: _authenticate),
            const SizedBox(height: AppSpacing.md),
            TextButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('Volver', style: TextStyle(color: AppColors.textMuted)),
            ),
          ],
        ),
      ),
    );
  }
}
