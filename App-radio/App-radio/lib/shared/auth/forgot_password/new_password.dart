import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:doliv_social/core/routes.dart';
import 'package:doliv_social/core/api_config.dart';
import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/shared/auth/widgets/auth_form_panel.dart';
import 'package:doliv_social/shared/auth/widgets/auth_header.dart';
import 'package:doliv_social/shared/auth/widgets/password_strength_meter.dart';

/// Paso 3 de 3: elegir la contraseña nueva.
class ChangePassword extends StatefulWidget {
  final String email;
  const ChangePassword({super.key, required this.email});

  @override
  State<ChangePassword> createState() => _ChangePasswordState();
}

class _ChangePasswordState extends State<ChangePassword> {
  final TextEditingController newPasswordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscure = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Future<String?> _saveOnServer(String password, String confirm) async {
    final String apiUrl = '$kBaseUrl/user/newPassword/${widget.email}';
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'newPassword': password, 'confirmPassword': confirm}),
      );
      if (response.statusCode == 200) return null;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['error'] != null) {
          return decoded['error'].toString();
        }
      } catch (_) {}
      return 'No se pudo cambiar la contraseña (${response.statusCode})';
    } catch (_) {
      return 'Sin conexión con el servidor';
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    setState(() => _isLoading = true);
    final error = await _saveOnServer(
      newPasswordController.text,
      confirmPasswordController.text,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.error),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Contraseña cambiada. Ya puedes iniciar sesión.')),
    );
    // Se vacía la pila: las tres pantallas de recuperación ya no tienen
    // sentido detrás del login.
    Navigator.pushNamedAndRemoveUntil(
      context,
      MyRoutes.loginRoutes,
      (route) => false,
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
            station: AuthStation.resetPassword,
            title: 'Crea una nueva contraseña',
            subtitle: 'Debe ser distinta a la que usabas antes.',
          ),
          const SizedBox(height: AppSpacing.xl),
          Form(
            key: _formKey,
            child: AuthFormPanel(
              children: [
                AuthField(
                  label: 'Nueva contraseña',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppTextField(
                        controller: newPasswordController,
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
                      PasswordStrengthMeter(password: newPasswordController.text),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                AuthField(
                  label: 'Confirmar contraseña',
                  child: AppTextField(
                    controller: confirmPasswordController,
                    obscured: _obscureConfirm,
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: PasswordVisibilityToggle(
                      obscured: _obscureConfirm,
                      onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                    hintText: 'Repite la contraseña',
                    validator: (value) => value != newPasswordController.text
                        ? 'Las contraseñas no coinciden'
                        : null,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  label: 'Guardar contraseña',
                  loading: _isLoading,
                  onPressed: _isLoading ? null : _save,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}
