import 'package:flutter/material.dart';
import '../tokens/colors.dart';
import '../tokens/spacing.dart';

/// Separador de día dentro de un chat, al estilo WhatsApp: una píldora
/// centrada con "HOY", "AYER" o la fecha, que aparece cada vez que cambia
/// el día entre un mensaje y el siguiente.
class DayDivider extends StatelessWidget {
  const DayDivider({super.key, required this.label});

  final String label;

  /// A partir de una fecha, arma la misma etiqueta que usa WhatsApp: "HOY"
  /// si es el día de hoy, "AYER" si fue ayer, el nombre del día si cayó
  /// dentro de la última semana, o `dd/mm/aaaa` para cualquier otro caso.
  static String labelForDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    final diff = today.difference(day).inDays;

    if (diff == 0) return 'HOY';
    if (diff == 1) return 'AYER';
    if (diff > 1 && diff < 7) {
      const names = [
        'LUNES',
        'MARTES',
        'MIÉRCOLES',
        'JUEVES',
        'VIERNES',
        'SÁBADO',
        'DOMINGO',
      ];
      return names[date.weekday - 1];
    }
    final two = (int n) => n.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: AppColors.surfaceBorder),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}
