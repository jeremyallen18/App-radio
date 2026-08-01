import 'package:flutter/material.dart';

class AppColors {
  static const Color darkBackground = Color(0xFF0B1330);
  static const Color darkField = Color(0xFF141C3F);
  static const Color darkFieldBorder = Color(0xFF243060);
  static const Color darkMuted = Color(0xFF8993B5);
  static const Color white = Color(0xFFFFFFFF);

  static const Color accentIndigo = Color(0xFF1657D6);
  static const Color accentIndigoLight = Color(0xFF3E7BFA);
  static const Color accentBlue = Color(0xFF0A3A8C);

  static const LinearGradient buttonGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [accentIndigoLight, accentBlue],
  );
}
