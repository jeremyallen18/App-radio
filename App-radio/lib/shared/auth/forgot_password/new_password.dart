import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:doliv_social/shared/auth/login.dart';
import 'package:doliv_social/core/api_config.dart';
import 'package:doliv_social/design/design.dart';

class ChangePassword extends StatefulWidget {
  final String email;
  const ChangePassword({super.key, required this.email});

  @override
  State<ChangePassword> createState() => _ChangePasswordState();
}

class _ChangePasswordState extends State<ChangePassword> {
  final TextEditingController newPasswordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  Future<String?> takePassAPI(String password, String confirmpass) async {
    final String apiUrl =
        '$kBaseUrl/user/newPassword/${widget.email}';

    var body = jsonEncode({
      "newPassword": password,
      "confirmPassword": confirmpass,
    });
    var headers = {
      'Content-Type': 'application/json',
    };

    try {
      var response =
          await http.post(Uri.parse(apiUrl), headers: headers, body: body);

      if (response.statusCode == 200) {
        print('Password changed successfully');
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

  void _passwordchange(BuildContext context) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);
    String password = newPasswordController.text;
    String? error =
        await takePassAPI(password, confirmPasswordController.text);
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
        const SnackBar(
          content: Text('¡Contraseña cambiada con éxito!'),
        ),
      );
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const Login(),
        ),
      );
    }
  }

  bool obscureText = true;
  bool obscureText2 = true;

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
            "Último paso,",
            style: TextStyle(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w400,
              fontSize: 16,
            ),
          ),
          const Text(
            "Crea una nueva contraseña",
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 26,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            "Debe ser distinta a la que usabas antes.",
            style: TextStyle(color: AppColors.textMuted, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: heightOfScreen * 0.05),
          Form(
            key: _formKey,
            child: Column(
              children: [
                AppTextField(
                  controller: newPasswordController,
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
                  hintText: "Nueva contraseña",
                  validator: (value) {
                    if ((value ?? '').length < 6) {
                      return 'Mínimo 6 caracteres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                AppTextField(
                  controller: confirmPasswordController,
                  obscured: obscureText2,
                  prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textMuted),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscureText2 ? Icons.visibility_off : Icons.visibility,
                      color: AppColors.textMuted,
                    ),
                    onPressed: () {
                      setState(() {
                        obscureText2 = !obscureText2;
                      });
                    },
                  ),
                  hintText: "Confirmar contraseña",
                  validator: (value) {
                    if (value != newPasswordController.text) {
                      return 'Las contraseñas no coinciden';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 28),
                AppButton(
                  label: _isLoading ? 'Guardando...' : 'Restablecer contraseña',
                  loading: _isLoading,
                  onPressed: _isLoading ? null : () => _passwordchange(context),
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
