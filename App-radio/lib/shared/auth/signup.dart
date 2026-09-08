import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:doliv_social/core/routes.dart';
import 'package:doliv_social/core/api_config.dart';
import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/shared/auth/widgets/auth_form_panel.dart';
import 'package:doliv_social/shared/auth/widgets/auth_header.dart';
import 'package:doliv_social/shared/auth/widgets/password_strength_meter.dart';

class SignUp extends StatefulWidget {
  const SignUp({super.key});

  @override
  State<SignUp> createState() => _SignUpState();
}

class _SignUpState extends State<SignUp> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passController = TextEditingController();
  final TextEditingController confirmController = TextEditingController();

  bool _isLoading = false;
  bool _obscure = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    setState(() => _isLoading = true);
    const String apiUrl = '$kBaseUrl/user/signup';
    http.Response response;
    try {
      response = await http.post(
        Uri.parse(apiUrl),
        body: {
          'name': nameController.text.trim(),
          'email': emailController.text.trim(),
          'password': passController.text,
        },
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sin conexión con el servidor')),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(response.body)),
    );
    if (response.statusCode == 200) {
      await Navigator.pushNamed(context, MyRoutes.loginRoutes);
    }
  }

  @override
  Widget build(BuildContext context) {
    final heightOfScreen = MediaQuery.of(context).size.height;

    return AppScaffold(
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: heightOfScreen * 0.03),
          const AuthHeader(
            station: AuthStation.signUp,
            title: 'Crea tu cuenta',
            subtitle: 'Entra a la cabina con tu equipo.',
          ),
          const SizedBox(height: AppSpacing.xl),
          Form(
            key: _formKey,
            child: AuthFormPanel(
              children: [
                AuthField(
                  label: 'Nombre',
                  child: AppTextField(
                    controller: nameController,
                    prefixIcon: const Icon(Icons.person_outline_rounded),
                    hintText: 'Cómo te llaman en la radio',
                    validator: (value) =>
                        (value ?? '').trim().isEmpty ? 'Ingresa tu nombre' : null,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
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
                const SizedBox(height: AppSpacing.lg),
                AuthField(
                  label: 'Contraseña',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppTextField(
                        controller: passController,
                        obscured: _obscure,
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: PasswordVisibilityToggle(
                          obscured: _obscure,
                          onToggle: () => setState(() => _obscure = !_obscure),
                        ),
                        hintText: 'Mínimo 6 caracteres',
                        validator: AuthValidators.password,
                        onChanged: (_) => setState(() {}),
                      ),
                      PasswordStrengthMeter(password: passController.text),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                AuthField(
                  label: 'Confirmar contraseña',
                  child: AppTextField(
                    controller: confirmController,
                    obscured: _obscureConfirm,
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: PasswordVisibilityToggle(
                      obscured: _obscureConfirm,
                      onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                    hintText: 'Repite la contraseña',
                    validator: (value) =>
                        value != passController.text ? 'Las contraseñas no coinciden' : null,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  label: 'Crear cuenta',
                  loading: _isLoading,
                  onPressed: _isLoading ? null : _signUp,
                ),
                const SizedBox(height: AppSpacing.md),
                const Text(
                  'Al crear tu cuenta aceptas los términos y condiciones.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AuthFooterLink(
            prompt: '¿Ya tienes una cuenta?',
            action: 'Iniciar sesión',
            onTap: () => Navigator.pushReplacementNamed(context, MyRoutes.loginRoutes),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}
