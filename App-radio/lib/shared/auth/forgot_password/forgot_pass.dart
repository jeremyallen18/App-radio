import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:doliv_social/shared/auth/forgot_password/otp_verify.dart';
import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/core/api_config.dart';

class ResetPass extends StatefulWidget {
  const ResetPass({Key? key}) : super(key: key);

  @override
  State<ResetPass> createState() => _ResetPassState();
}

class _ResetPassState extends State<ResetPass> {
  TextEditingController emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  Future<String?> takeEmailAPI(String email) async {
    const String apiUrl =
        '$kBaseUrl/user/resetPassword';
    var body = jsonEncode({
      "email": email,
    });
    var headers = {
      'Content-Type': 'application/json',
    };
    try {
      var response =
          await http.post(Uri.parse(apiUrl), headers: headers, body: body);

      if (response.statusCode == 200) {
        print('OTP sent successfully');
        print(jsonDecode(response.body));
        return null;
      } else {
        print('Error: ${response.statusCode}');
        print(jsonDecode(response.body));
        return jsonDecode(response.body)['error'];
      }
    } catch (e) {
      print('Error: $e');
      return 'An error occurred';
    }
  }

  void _resetPassword() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);
    String email = emailController.text.trim();
    String? error = await takeEmailAPI(email);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $error'),
          backgroundColor: Colors.red,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Código OTP enviado a $email'),
        ),
      );
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OTPVerify(
            email: email,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final heightOfScreen = MediaQuery.of(context).size.height;

    return AppScaffold(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      scrollable: true,
      body: Column(
        children: [
          SizedBox(height: heightOfScreen * 0.06),
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
                "lib/assets/reset.png",
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "Recuperar acceso,",
            style: TextStyle(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w400,
              fontSize: 16,
            ),
          ),
          const Text(
            "¿Olvidaste tu contraseña?",
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 26,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Escribe el correo de tu cuenta y te enviaremos un código para recuperarla.",
            style: TextStyle(color: AppColors.textMuted, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: heightOfScreen * 0.05),
          Form(
            key: _formKey,
            child: Column(
              children: [
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
                const SizedBox(height: 28),
                AppButton(
                  label: _isLoading ? 'Enviando...' : 'Enviar código',
                  loading: _isLoading,
                  onPressed: _isLoading ? null : _resetPassword,
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
