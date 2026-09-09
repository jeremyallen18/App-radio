import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show TextInput;
import 'package:http/http.dart' as http;
import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/core/routes.dart';
import 'package:doliv_social/core/api_config.dart';
import 'package:doliv_social/core/push/push_service.dart';
import 'package:doliv_social/core/remember_me.dart';
import 'package:doliv_social/core/session.dart';
import 'package:doliv_social/core/session_keys.dart';
import 'package:doliv_social/services/auth_service.dart';
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
  void initState() {
    super.initState();
    _restoreRememberMeCheck();
  }

  /// Restaura solo el estado del check "Recordar". El correo y la contrasena
  /// NO se recuperan aca: los guarda y los ofrece el gestor de contrasenas del
  /// sistema (Android Autofill / iCloud Llavero) sobre los campos con
  /// `autofillHints`.
  Future<void> _restoreRememberMeCheck() async {
    final remember = await RememberMe.loadFlag();
    if (!remember || !mounted) return;
    setState(() => _rememberMe = true);
  }

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
      // Solo recuerda el estado del check. El correo y la contrasena se los
      // lleva el gestor de contrasenas del sistema: al cerrar el contexto de
      // autofill con `shouldSave`, Android/iOS ofrecen guardarlos si el check
      // esta activo. No afecta a la permanencia de la sesion.
      await RememberMe.saveFlag(_rememberMe);
      TextInput.finishAutofillContext(shouldSave: _rememberMe);
      await secureStorage.writeSecureData(
          emailVerifiedKey, emailVerified ? '1' : '0');
      // No bloquea el login: si /user/me falla, el rol simplemente queda
      // sin cachear y se puede volver a pedir más adelante.
      unawaited(Session.fetchCurrentUser(accessToken));
      // Igual que en main.dart: el push solo aplica en Android nativo; en
      // escritorio/web `init()` fallaría y dejaría un log de error en cada login.
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        unawaited(PushService.instance.init());
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inicio de sesión exitoso')),
      );
      await Navigator.pushNamedAndRemoveUntil(
        context,
        MyRoutes.bottomNavBar,
        (route) => false,
      );
    } else if (response.statusCode == 403 &&
        _isUnverifiedEmailResponse(response.body)) {
      // El backend NO emite token si el correo no está verificado; ya
      // reenvió el enlace (con su límite anti-abuso) al recibir este intento.
      _showUnverifiedEmailNotice(emailController.text.trim());
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Correo o contraseña incorrectos')),
      );
    }
  }

  bool _isUnverifiedEmailResponse(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map && decoded['code'] == 'EMAIL_UNVERIFIED';
    } catch (_) {
      return false;
    }
  }

  void _showUnverifiedEmailNotice(String email) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 8),
          content: const Text(
            'Verifica tu correo antes de iniciar sesión. Te reenviamos el '
            'enlace: revisa tu bandeja y la carpeta de spam.',
          ),
          action: SnackBarAction(
            label: 'Reenviar',
            onPressed: () async {
              await AuthApi.resendVerification(email);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Si la cuenta existe y sigue sin verificar, te enviamos '
                    'un nuevo enlace.',
                  ),
                ),
              );
            },
          ),
        ),
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
            station: AuthStation.login,
            title: 'Iniciar sesión',
            subtitle: 'Tu equipo ya está al aire.',
          ),
          const SizedBox(height: AppSpacing.xl),
          Form(
            key: _formKey,
            // `AutofillGroup`: cierra el contexto de autocompletado como una
            // unidad (correo + contraseña) para que el gestor del sistema
            // ofrezca guardarlos juntos tras un login correcto.
            child: AutofillGroup(
              child: AuthFormPanel(
                children: [
                  AuthField(
                    label: 'Correo',
                    child: AppTextField(
                      controller: emailController,
                      textInputType: TextInputType.emailAddress,
                      autofillHints: const [
                        AutofillHints.username,
                        AutofillHints.email,
                      ],
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
                      autofillHints: const [AutofillHints.password],
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
                  // `Wrap` (no `Row`): con fuente del sistema grande o "zoom de
                  // pantalla" (Honor/EMUI, accesibilidad) el enlace no cabe junto
                  // al checkbox y antes se pintaba encima. Ahora baja a su propia
                  // línea; y si aun así no cabe, su texto se parte en dos renglones
                  // en vez de desbordarse.
                  LayoutBuilder(
                    builder: (context, constraints) => Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(AppRadius.chip),
                          onTap: () =>
                              setState(() => _rememberMe = !_rememberMe),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Checkbox(
                                value: _rememberMe,
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                onChanged: (v) =>
                                    setState(() => _rememberMe = v ?? false),
                              ),
                              const Text(
                                'Recuérdame',
                                style: TextStyle(
                                    color: AppColors.textMuted, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              Navigator.pushNamed(context, MyRoutes.reset),
                          child: ConstrainedBox(
                            constraints:
                                BoxConstraints(maxWidth: constraints.maxWidth),
                            child: const Text(
                              '¿Olvidaste tu contraseña?',
                              textAlign: TextAlign.end,
                              style: TextStyle(
                                  color: AppColors.accentStrong, fontSize: 13),
                            ),
                          ),
                        ),
                      ],
                    ),
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
          ),
          const SizedBox(height: AppSpacing.lg),
          AuthFooterLink(
            prompt: '¿No tienes cuenta?',
            action: 'Regístrate',
            onTap: () =>
                Navigator.pushReplacementNamed(context, MyRoutes.signUpRoutes),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}
