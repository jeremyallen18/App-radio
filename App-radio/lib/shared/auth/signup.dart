import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:doliv_social/core/Routes.dart';
import 'package:doliv_social/core/api_config.dart';
import 'package:doliv_social/design/design.dart';

class SignUp extends StatefulWidget {
  const SignUp({super.key});

  @override
  State<SignUp> createState() => _SignUpState();
}

class _SignUpState extends State<SignUp> {
  bool _isLoading = false;

  Future<void> SignApi() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    const String apiUrl = '$kBaseUrl/user/signup';
    final response = await http.post(
        Uri.parse(apiUrl),
        body: ({
          'name': nameController.text,
          'email': emailController.text,
          'password': passController.text,
        })
    );
    if (!mounted) return;
    setState(() => _isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(response.body)),
    );
    if (response.statusCode == 200) {
      print('API Response: ${response.body}');
      await Navigator.pushNamed(context, MyRoutes.LoginRoutes);
    } else {
      print('Failed to join the team. Status Code: ${response.statusCode}');
      print('Error Message: ${response.body}');
    }
  }

  final _formKey = GlobalKey<FormState>();
  TextEditingController emailController = TextEditingController();
  TextEditingController nameController = TextEditingController();
  TextEditingController passController = TextEditingController();
  TextEditingController comfpassController = TextEditingController();

  bool obscureText = true;
  bool obscureConfirmText = true;

  @override
  Widget build(BuildContext context) {
    final heightOfScreen = MediaQuery.of(context).size.height;

    return AppScaffold(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      scrollable: true,
      body: Column(
        children: [
          SizedBox(height: heightOfScreen * 0.05),
          Center(
            child: Container(
              width: 96,
              height: 96,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.textPrimary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Image.asset(
                "lib/assets/signup.png",
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "Crea tu cuenta,",
            style: TextStyle(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w400,
              fontSize: 16,
            ),
          ),
          const Text(
            "Registrarse",
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 28,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Al continuar aceptas los términos y condiciones",
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: heightOfScreen * 0.04),
          Form(
            key: _formKey,
            child: Column(
              children: [
                AppTextField(
                  controller: nameController,
                  prefixIcon: const Icon(Icons.person_outline, color: AppColors.textMuted),
                  hintText: "Nombre de usuario",
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return 'Ingresa tu nombre';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                AppTextField(
                  controller: emailController,
                  textInputType: TextInputType.emailAddress,
                  prefixIcon: const Icon(Icons.email_outlined, color: AppColors.textMuted),
                  hintText: "Correo electrónico",
                  validator: (value) {
                    final email = value?.trim() ?? '';
                    if (email.isEmpty) {
                      return 'Ingresa tu correo';
                    }
                    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                      return 'Correo inválido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                AppTextField(
                  controller: passController,
                  obscured: obscureText,
                  prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textMuted),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscureText ? Icons.visibility_off : Icons.visibility,
                      color: AppColors.textMuted,
                    ),
                    onPressed: () {
                      setState(() {
                        obscureText = !obscureText;
                      });
                    },
                  ),
                  hintText: "Contraseña",
                  validator: (value) {
                    if ((value ?? '').length < 6) {
                      return 'Mínimo 6 caracteres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                AppTextField(
                  controller: comfpassController,
                  obscured: obscureConfirmText,
                  prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textMuted),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscureConfirmText ? Icons.visibility_off : Icons.visibility,
                      color: AppColors.textMuted,
                    ),
                    onPressed: () {
                      setState(() {
                        obscureConfirmText = !obscureConfirmText;
                      });
                    },
                  ),
                  hintText: "Confirmar contraseña",
                  validator: (value) {
                    if (value != passController.text) {
                      return 'Las contraseñas no coinciden';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 28),
                AppButton(
                  label: _isLoading ? 'Cargando...' : "Registrarse",
                  loading: _isLoading,
                  onPressed: _isLoading ? null : SignApi,
                ),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: () => Navigator.pushReplacementNamed(context, MyRoutes.LoginRoutes),
                  child: RichText(
                    text: const TextSpan(
                      children: [
                        TextSpan(
                          text: "¿Ya tienes una cuenta? ",
                          style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                        ),
                        TextSpan(
                          text: "Iniciar sesión",
                          style: TextStyle(
                            color: AppColors.accentStrong,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
