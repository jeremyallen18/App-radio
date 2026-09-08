import 'package:flutter/material.dart';
import 'package:doliv_social/shared/auth/forgot_password/otp_verify.dart';
import 'package:doliv_social/shared/auth/forgot_password/reset_api.dart';
import 'package:doliv_social/shared/auth/widgets/auth_form_panel.dart';
import 'package:doliv_social/shared/auth/widgets/auth_header.dart';
import 'package:doliv_social/design/design.dart';

/// Paso 1 de 3 de la recuperación: pedir el correo y enviar el código.
class ResetPass extends StatefulWidget {
  const ResetPass({super.key});

  @override
  State<ResetPass> createState() => _ResetPassState();
}

class _ResetPassState extends State<ResetPass> {
  final TextEditingController emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    setState(() => _isLoading = true);
    final email = emailController.text.trim();
    final error = await sendResetCode(email);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.error),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Código enviado a $email')),
    );
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => OTPVerify(email: email)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final heightOfScreen = MediaQuery.of(context).size.height;

    return AppScaffold(
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: heightOfScreen * 0.04),
          const AuthHeader(
            station: AuthStation.resetEmail,
            title: '¿Olvidaste tu contraseña?',
            subtitle:
                'Escribe el correo de tu cuenta. Te enviaremos un código de 6 dígitos que vence en 10 minutos.',
          ),
          const SizedBox(height: AppSpacing.xl),
          Form(
            key: _formKey,
            child: AuthFormPanel(
              children: [
                AuthField(
                  label: 'Correo',
                  child: AppTextField(
                    controller: emailController,
                    textInputType: TextInputType.emailAddress,
                    prefixIcon: const Icon(Icons.alternate_email_rounded),
                    hintText: 'nombre@radiodoliv.com',
                    validator: AuthValidators.email,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  label: 'Enviar código',
                  loading: _isLoading,
                  onPressed: _isLoading ? null : _sendCode,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AuthFooterLink(
            prompt: '¿La recordaste?',
            action: 'Volver a iniciar sesión',
            onTap: () => Navigator.maybePop(context),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}
