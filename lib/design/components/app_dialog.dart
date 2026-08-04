import 'package:flutter/material.dart';
import '../tokens/colors.dart';

/// Diálogo de confirmación estándar. Devuelve `true`/`false`/`null`
/// (cancelado tocando fuera). Reemplaza al `AlertDialog` repetido a mano en
/// `tasks.dart` y `teamDetail.dart`.
Future<bool?> showAppConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirmar',
  String cancelLabel = 'Cancelar',
  bool danger = false,
}) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(
            cancelLabel,
            style: const TextStyle(color: AppColors.textMuted),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(
            confirmLabel,
            style: TextStyle(color: danger ? AppColors.error : AppColors.accentStrong),
          ),
        ),
      ],
    ),
  );
}
