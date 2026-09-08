import 'package:flutter/material.dart';
import 'package:doliv_social/design/tokens/colors.dart';

/// Campo de texto estándar. Reemplaza a `widgets/custom_text_form_field.dart`
/// — misma API, apoyada en `inputDecorationTheme` en vez de repetir bordes.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.prefixIcon,
    this.suffixIcon,
    this.suffixText,
    this.hintText,
    this.obscured = false,
    this.textInputType,
    this.validator,
    this.textStyle,
    this.maxLines = 1,
    this.readOnly = false,
    this.onTap,
    this.onChanged,
  });

  final TextEditingController? controller;
  final Widget? prefixIcon;
  final Widget? suffixIcon;

  /// Sufijo de solo lectura dentro del campo (p. ej. la unidad "m").
  final String? suffixText;
  final String? hintText;
  final bool obscured;
  final TextInputType? textInputType;
  final FormFieldValidator<String>? validator;
  final TextStyle? textStyle;
  final int maxLines;
  final bool readOnly;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;

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
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        suffixText: suffixText,
        suffixStyle: const TextStyle(
          color: AppColors.textMuted,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
