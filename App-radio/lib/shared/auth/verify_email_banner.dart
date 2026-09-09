import 'dart:async';

import 'package:flutter/material.dart';

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/core/session.dart';
import 'package:doliv_social/core/session_keys.dart'
    show secureStorage, key, emailVerifiedKey;
import 'package:doliv_social/services/auth_service.dart';

/// Aviso fijo en la parte de arriba del shell cuando la cuenta no ha
/// verificado su correo. No bloquea la app; ofrece reenviar el enlace y
/// volver a comprobar. Se oculta solo (SizedBox) cuando el correo ya está
/// verificado o no se sabe todavía.
class VerifyEmailBanner extends StatefulWidget {
  const VerifyEmailBanner({super.key});

  @override
  State<VerifyEmailBanner> createState() => _VerifyEmailBannerState();
}

class _VerifyEmailBannerState extends State<VerifyEmailBanner>
    with WidgetsBindingObserver {
  /// null = aún sin determinar (no se muestra nada).
  bool? _verified;
  String? _email;
  bool _sending = false;
  bool _rechecking = false;
  int _cooldown = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _primeFromCache();
    _check();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Al volver a la app (p. ej. tras abrir el enlace del correo en el
    // navegador) se vuelve a comprobar contra el backend.
    if (state == AppLifecycleState.resumed && (_verified != true)) _check();
  }

  Future<void> _primeFromCache() async {
    final flag = await secureStorage.readSecureData(emailVerifiedKey);
    if (!mounted) return;
    // Ausente => se asume verificado (sesiones previas a esta función).
    setState(() => _verified = flag == null ? true : flag == '1');
  }

  Future<void> _check() async {
    final token = await secureStorage.readSecureData(key);
    if (token == null) return;
    final profile = await Session.fetchCurrentUser(token as String);
    if (!mounted || profile == null) return;
    setState(() {
      _verified = profile.emailVerified;
      _email = profile.email;
    });
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldown = 60);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _cooldown--);
      if (_cooldown <= 0) t.cancel();
    });
  }

  Future<void> _resend() async {
    final email = _email;
    if (email == null || _sending || _cooldown > 0) return;
    setState(() => _sending = true);
    await AuthApi.resendVerification(email);
    if (!mounted) return;
    setState(() => _sending = false);
    _startCooldown();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Te enviamos un nuevo enlace. Revisa tu correo.'),
      ),
    );
  }

  Future<void> _recheck() async {
    if (_rechecking) return;
    setState(() => _rechecking = true);
    await _check();
    if (!mounted) return;
    setState(() => _rechecking = false);
    if (_verified == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Correo verificado!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // El aviso entra/sale con un despliegue vertical suave en vez de aparecer
    // de golpe y empujar el contenido.
    return AnimatedSize(
      duration: context.reduceMotion ? Duration.zero : AppDurations.medium,
      curve: AppCurves.standard,
      alignment: Alignment.topCenter,
      child: _verified != false
          ? const SizedBox(width: double.infinity)
          : AppFadeIn(
              offset: const Offset(0, -8), child: _buildBanner(context)),
    );
  }

  Widget _buildBanner(BuildContext context) {
    return Material(
      color: AppColors.warning.withValues(alpha: 0.14),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.mark_email_unread_outlined,
                    size: 18, color: AppColors.warning),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Verifica tu correo',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _email == null
                          ? 'Abre el enlace que te enviamos por correo para activar tu cuenta.'
                          : 'Abre el enlace enviado a $_email. Algunas acciones lo requieren.',
                      style:
                          TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: AppSpacing.sm,
                      children: [
                        TextButton(
                          onPressed:
                              (_sending || _cooldown > 0 || _email == null)
                                  ? null
                                  : _resend,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 0),
                            minimumSize: const Size(0, 32),
                          ),
                          child: Text(
                            _cooldown > 0
                                ? 'Reenviar (${_cooldown}s)'
                                : _sending
                                    ? 'Enviando…'
                                    : 'Reenviar correo',
                          ),
                        ),
                        TextButton(
                          onPressed: _rechecking ? null : _recheck,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 0),
                            minimumSize: const Size(0, 32),
                          ),
                          child: Text(
                              _rechecking ? 'Comprobando…' : 'Ya verifiqué'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
