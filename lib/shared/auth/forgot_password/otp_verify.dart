import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:doliv_social/shared/auth/forgot_password/new_password.dart';
import 'package:doliv_social/core/api_config.dart';
import 'package:doliv_social/design/design.dart';

class OTPVerify extends StatefulWidget {
  final String email;

  const OTPVerify({super.key, required this.email});

  @override
  State<OTPVerify> createState() => _OTPVerifyState();
}

class _OTPVerifyState extends State<OTPVerify> {
  final TextEditingController otpController = TextEditingController();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  Future<String?> takeOTPAPI(String otp) async {
    final String apiUrl =
        '$kBaseUrl/user/verifyOTP/${widget.email}';
    var body = jsonEncode({
      "OTP": otp,
    });
    var headers = {'Content-Type': 'application/json'};
    try {
      var response =
          await http.post(Uri.parse(apiUrl), headers: headers, body: body);

      if (response.statusCode == 200) {
        print('OTP verified');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Código OTP verificado"),
          ),
        );
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChangePassword(
              email: widget.email,
            ),
          ),
        );
        print(jsonDecode(response.body));
        return null;
      } else {
        print('Error: ${response.statusCode}');
        print(jsonDecode(response.body));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${response.body}'),
            backgroundColor: Colors.red,
          ),
        );
        return jsonDecode(response.body)['error'];
      }
    } catch (e) {
      print('Error: $e');
    }
    return null;
  }

  void _verifyOTP(BuildContext context) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);
    String otp = otpController.text.trim();
    String? error = await takeOTPAPI(otp);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $error'),
          backgroundColor: Colors.red,
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
            "Casi listo,",
            style: TextStyle(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w400,
              fontSize: 16,
            ),
          ),
          const Text(
            "Ingresa el código",
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 26,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Te enviamos un código OTP a ${widget.email}",
            style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: heightOfScreen * 0.05),
          Form(
            key: _formKey,
            child: Column(
              children: [
                AppTextField(
                  controller: otpController,
                  textInputType: TextInputType.number,
                  prefixIcon: const Icon(Icons.pin_outlined, color: AppColors.textMuted),
                  hintText: "Código OTP",
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Ingresa el código OTP';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 28),
                AppButton(
                  label: _isLoading ? 'Verificando...' : 'Verificar y continuar',
                  loading: _isLoading,
                  onPressed: _isLoading ? null : () => _verifyOTP(context),
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
