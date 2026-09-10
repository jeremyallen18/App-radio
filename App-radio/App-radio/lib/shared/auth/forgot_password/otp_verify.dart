import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:doliv_social/shared/auth/forgot_password/new_password.dart';
import 'package:doliv_social/shared/auth/forgot_password/reset_api.dart';
import 'package:doliv_social/shared/auth/widgets/auth_form_panel.dart';
import 'package:doliv_social/shared/auth/widgets/auth_header.dart';
import 'package:doliv_social/shared/auth/widgets/otp_code_field.dart';
import 'package:doliv_social/core/api_config.dart';
import 'package:doliv_social/design/design.dart';

/// Paso 2 de 3: verificar el código de 6 dígitos enviado a [email].
class OTPVerify extends StatefulWidget {
  final String email;

  const OTPVerify({super.key, required this.email});

  @override
  State<OTPVerify> createState() => _OTPVerifyState();
}

class _OTPVerifyState extends State<OTPVerify> {
  static const int _resendCooldownSeconds = 60;
  static const int _codeLength = 6;

  final TextEditingController otpController = TextEditingController();
  bool _isLoading = false;
  bool _resending = false;
  int _cooldown = _resendCooldownSeconds;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    otpController.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldown = _resendCooldownSeconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_cooldown <= 1) {
        t.cancel();
        setState(() => _cooldown = 0);
      } else {
        setState(() => _cooldown--);
      }
    });
  }

  Future<String?> _verifyOnServer(String otp) async {
    final String apiUrl = '$kBaseUrl/user/verifyOTP/${widget.email}';
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'OTP': otp}),
      );
      if (response.statusCode == 200) return null;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['error'] != null) {
          return decoded['error'].toString();
        }
      } catch (_) {}
      return 'Código incorrecto o vencido';
    } catch (_) {
      return 'Sin conexión con el servidor';
    }
  }

  Future<void> _verify() async {
    final otp = otpController.text.trim();
    if (otp.length != _codeLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe los 6 dígitos del código')),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);
    final error = await _verifyOnServer(otp);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.error),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ChangePassword(email: widget.email)),
    );
  }

  Future<void> _resend() async {
    setState(() => _resending = true);
    final error = await sendResetCode(widget.email);
    if (!mounted) return;
    setState(() => _resending = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.error),
      );
      return;
    }
    otpController.clear();
    _startCooldown();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Te enviamos un código nuevo')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final heightOfScreen = MediaQuery.of(context).size.height;
    final canResend = _cooldown == 0 && !_resending && !_isLoading;

    return AppScaffold(
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: heightOfScreen * 0.04),
          AuthHeader(
            station: AuthStation.resetCode,
            title: 'Ingresa el código',
            subtitle: 'Lo enviamos a ${widget.email}',
          ),
          const SizedBox(height: AppSpacing.xl),
          AuthFormPanel(
            children: [
              AuthField(
                label: 'Código de 6 dígitos',
                child: OtpCodeField(
                  controller: otpController,
                  length: _codeLength,
                  onCompleted: (_) {
                    if (!_isLoading) _verify();
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: 'Verificar y continuar',
                loading: _isLoading,
                onPressed: _isLoading ? null : _verify,
              ),
              const SizedBox(height: AppSpacing.md),
              Center(
                child: TextButton(
                  onPressed: canResend ? _resend : null,
                  child: Text(
                    _resending
                        ? 'Reenviando...'
                        : _cooldown > 0
                            ? 'Reenviar código en ${_cooldown}s'
                            : 'Reenviar código',
                    style: TextStyle(
                      color: canResend ? AppColors.accentStrong : AppColors.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AuthFooterLink(
            prompt: '¿Correo equivocado?',
            action: 'Cambiar correo',
            onTap: () => Navigator.maybePop(context),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}
