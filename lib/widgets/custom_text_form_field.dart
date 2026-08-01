import 'package:flutter/material.dart';
import '../utils/colors.dart';

class CustomTextFormField extends StatelessWidget {
  final TextEditingController? controller;
  final TextStyle? textStyle;
  final TextStyle? hintTextStyle;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? hintText;
  final bool obscured;
  final TextInputType? textInputType;
  final FormFieldValidator<String>? validator;

  const CustomTextFormField({
    super.key,
    this.controller,
    this.prefixIcon,
    this.suffixIcon,
    this.textStyle,
    this.hintTextStyle,
    this.hintText,
    this.obscured = false,
    this.textInputType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      style: textStyle,
      cursorColor: AppColors.white,
      keyboardType: textInputType,
      validator: validator,
      obscureText: obscured,
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        filled: true,
        fillColor: AppColors.darkField,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.darkFieldBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.darkFieldBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.accentIndigoLight, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        hintText: hintText,
        hintStyle: hintTextStyle,
      ),
    );
  }
}
