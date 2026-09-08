import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/core/Routes.dart';
import 'package:doliv_social/core/api_config.dart';
import 'package:doliv_social/core/session.dart';
import 'package:doliv_social/core/session_keys.dart';
import 'package:doliv_social/shared/auth/widgets/auth_form_panel.dart';
import 'package:doliv_social/shared/auth/widgets/auth_header.dart';

// `secureStorage`, `key` y `rememberMeKey` se movieron a
// `core/session_keys.dart` (las usan servicios, APIs y `main.dart`). Se
// re-exportan aca para no romper los imports que ya apuntaban a este archivo.
export 'package:doliv_social/core/session_keys.dart'
    show secureStorage, key, rememberMeKey;

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _rememberMe = false;
  bool _isLoading = false;
  bool _obscure = true;

  @override
  void dispose() {
    emailController.dispose();
    passController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    setState(() => _isLoading = true);
    const String apiUrl = '$kBaseUrl/user/login';
    http.Response response;
    try {
      response = await http.post(
        Uri.parse(apiUrl),
        // Pide la respuesta enriquecida { token, emailVerified }. Sin esta
        // cabecera el backend responde el token como string a secas (contrato
        // histórico que respetan los builds ya instalados).
        headers: const {'X-Client-Features': 'login-object'},
        body: {
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

    if (response.statusCode == 200) {
      final dynamic decoded = jsonDecode(response.body);
      // El backend nuevo responde { token, emailVerified }; el viejo devolvía
      // el token como string a secas. Se admiten ambas formas.
      final String accessToken =
          decoded is Map ? decoded['token'].toString() : decoded.toString();
      final bool emailVerified =
          decoded is Map ? decoded['emailVerified'] == true : true;

      await secureStorage.writeSecureData(key, accessToken);
      await secureStorage.writeSecureData(rememberMeKey, _rememberMe ? '1' : '0');
      await secureStorage.writeSecureData(
          emailVerifiedKey, emailVerified ? '1' : '0');
      // No bloquea el login: si /user/me falla, el rol simplemente queda
      // sin cachear y se puede volver a pedir más adelante.
      unawaited(Session.fetchCurrentUser(accessToken));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inicio de sesión exitoso')),
      );
      await Navigator.pushNamedAndRemoveUntil(
        context,
        MyRoutes.BottomNavBar,
        (route) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Correo o contraseña incorrectos')),
      );
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
          SizedBox(height: heightOfScreen * 0.04),
          const AuthHeader(
            station: AuthStation.login,
            title: 'Iniciar sesión',
            subtitle: 'Tu equipo ya está al aire.',
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
                const SizedBox(height: AppSpacing.lg),
                AuthField(
                  label: 'Contraseña',
                  child: AppTextField(
                    controller: passController,
                    obscured: _obscure,
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: PasswordVisibilityToggle(
                      obscured: _obscure,
                      onToggle: () => setState(() => _obscure = !_obscure),
                    ),
                    hintText: 'Tu contraseña',
                    validator: AuthValidators.password,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(AppRadius.chip),
                        onTap: () => setState(() => _rememberMe = !_rememberMe),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Checkbox(
                              value: _rememberMe,
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              onChanged: (v) => setState(() => _rememberMe = v ?? false),
                            ),
                            const Text(
                              'Recuérdame',
                              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pushNamed(context, MyRoutes.Reset),
                      child: const Text(
                        '¿Olvidaste tu contraseña?',
                        style: TextStyle(color: AppColors.accentStrong, fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: 'Iniciar sesión',
                  loading: _isLoading,
                  onPressed: _isLoading ? null : _login,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AuthFooterLink(
            prompt: '¿No tienes cuenta?',
            action: 'Regístrate',
            onTap: () => Navigator.pushReplacementNamed(context, MyRoutes.SignUpRoutes),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}
