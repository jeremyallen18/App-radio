import 'package:flutter/material.dart';
import '../tokens/colors.dart';

/// Campo de texto estándar. Reemplaza a `widgets/custom_text_form_field.dart`
/// — misma API, apoyada en `inputDecorationTheme` en vez de repetir bordes.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.prefixIcon,
    this.suffixIcon,
    this.hintText,
    this.obscured = false,
    this.textInputType,
    this.validator,
    this.textStyle,
    this.maxLines = 1,
    this.readOnly = false,
    this.onTap,
  });

  final TextEditingController? controller;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? hintText;
  final bool obscured;
  final TextInputType? textInputType;
  final FormFieldValidator<String>? validator;
  final TextStyle? textStyle;
  final int maxLines;
  final bool readOnly;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      style: textStyle ?? const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500),
      cursorColor: AppColors.textPrimary,
      keyboardType: textInputType,
      validator: validator,
      obscureText: obscured,
      maxLines: obscured ? 1 : maxLines,
      readOnly: readOnly,
      onTap: onTap,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
      ),
    );
  }
}
