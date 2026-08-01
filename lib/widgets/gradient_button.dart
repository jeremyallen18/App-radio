import 'package:flutter/material.dart';
import '../utils/colors.dart';

class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.title,
    required this.onPressed,
    this.height = 50,
  });

  final String title;
  final VoidCallback? onPressed;
  final double height;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: AppColors.buttonGradient,
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: AppColors.accentIndigo.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: onPressed,
          child: Opacity(
            opacity: enabled ? 1 : 0.5,
            child: Center(
              child: Text(
                title,
                style: const TextStyle(
                  color: AppColors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
