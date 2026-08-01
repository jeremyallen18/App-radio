 import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/storeToken.dart';
import '../utils/Routes.dart';
import '../utils/api_config.dart';
import '../utils/colors.dart';
import '../widgets/custom_text_form_field.dart';
import '../widgets/gradient_button.dart';
// import 'package:brl_task4/screens/recaptcha.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

 final SecureStorage secureStorage=SecureStorage();
 String key= 'accessToken';
class _LoginState extends State<Login> {

  TextEditingController emailController =TextEditingController();
  TextEditingController passController =TextEditingController();
  bool _rememberMe = false;
  bool _isLoading = false;

  Future <void> LoginApi() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    const String apiUrl = '$kBaseUrl/user/login';
    final response = await http.post(
        Uri.parse(apiUrl),
        body:({
          'email':emailController.text,
          'password':passController.text,
        })
    );
    if (!mounted) return;
    setState(() => _isLoading = false);
      print(response.body);
    if (response.statusCode == 200) {

      dynamic generateResponse = jsonDecode(response.body);
      Token.fromJson(generateResponse);
      await secureStorage.writeSecureData(key,generateResponse);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Inicio de sesión exitoso"),),);
      print('API Response: ${response.body}');
      await Navigator.pushNamed(context, MyRoutes.BottomNavBar);

    } else {
      print('Failed to join the team. Status Code: ${response.statusCode}');
      print('Error Message: ${response.body}');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Correo o contraseña incorrectos")),
      );
    }
  }

  final _formKey = GlobalKey<FormState>();
  bool obscureText= true;
  @override
  Widget build(BuildContext context) {
    final heightOfScreen = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            children: [
              SizedBox(height: heightOfScreen * 0.06),
              Center(
                child: Container(
                  width: 96,
                  height: 96,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.white,
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
                    "lib/assets/login.png",
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                "Bienvenido,",
                style: TextStyle(
                  color: AppColors.darkMuted,
                  fontWeight: FontWeight.w400,
                  fontSize: 16,
                ),
              ),
              const Text(
                "Iniciar sesión",
                style: TextStyle(
                  color: AppColors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 28,
                ),
              ),
              SizedBox(height: heightOfScreen * 0.05),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    CustomTextFormField(
                      controller: emailController,
                      textInputType: TextInputType.emailAddress,
                      prefixIcon: const Icon(Icons.email_outlined, color: AppColors.darkMuted),
                      hintText: "Correo electrónico",
                      hintTextStyle: const TextStyle(color: AppColors.darkMuted, fontSize: 14),
                      textStyle: const TextStyle(color: AppColors.white, fontWeight: FontWeight.w500),
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
                    CustomTextFormField(
                      controller: passController,
                      obscured: obscureText,
                      prefixIcon: const Icon(Icons.lock_outline, color: AppColors.darkMuted),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureText ? Icons.visibility_off : Icons.visibility,
                          color: AppColors.darkMuted,
                        ),
                        onPressed: () {
                          setState(() {
                            obscureText = !obscureText;
                          });
                        },
                      ),
                      hintText: "Contraseña",
                      hintTextStyle: const TextStyle(color: AppColors.darkMuted, fontSize: 14),
                      textStyle: const TextStyle(color: AppColors.white, fontWeight: FontWeight.w500),
                      validator: (value) {
                        if ((value ?? '').length < 6) {
                          return 'Mínimo 6 caracteres';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Switch(
                              value: _rememberMe,
                              activeTrackColor: AppColors.accentIndigo,
                              onChanged: (value) => setState(() => _rememberMe = value),
                            ),
                            const Text(
                              "Recuérdame",
                              style: TextStyle(color: AppColors.darkMuted, fontSize: 12),
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pushNamed(context, MyRoutes.Reset);
                          },
                          child: const Text(
                            "¿Olvidaste tu contraseña?",
                            style: TextStyle(color: AppColors.accentIndigoLight, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    GradientButton(
                      title: _isLoading ? 'Cargando...' : "Iniciar sesión",
                      onPressed: _isLoading ? null : LoginApi,
                    ),
                    const SizedBox(height: 24),
                    GestureDetector(
                      onTap: () => Navigator.pushReplacementNamed(context, MyRoutes.SignUpRoutes),
                      child: RichText(
                        text: const TextSpan(
                          children: [
                            TextSpan(
                              text: "¿No tienes cuenta? ",
                              style: TextStyle(color: AppColors.darkMuted, fontSize: 14),
                            ),
                            TextSpan(
                              text: "Regístrate",
                              style: TextStyle(
                                color: AppColors.accentIndigoLight,
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
        ),
      ),
    );
  }
}
