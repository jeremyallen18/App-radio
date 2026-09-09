import 'dart:io';

import 'package:flutter/material.dart';

import 'package:doliv_social/design/design.dart';

/// Resultado de la hoja de confirmación de evidencia.
enum EvidenceChoice { confirm, replace, cancel }

/// Hoja inferior que previsualiza la foto elegida como evidencia y pide una
/// decisión explícita antes de subirla: "Enviar evidencia", "Cambiar foto" o
/// "Cancelar". Seleccionar la foto nunca la sube; solo `confirm` lo hace.
class EvidenceConfirmSheet extends StatelessWidget {
  const EvidenceConfirmSheet({
    super.key,
    required this.taskTitle,
    required this.file,
  });

  final String taskTitle;
  final File file;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Revisa la evidencia',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Se adjuntará a "$taskTitle" al confirmar. Todavía no se ha subido.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.card),
              child: Image.file(
                file,
                height: 240,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 240,
                  alignment: Alignment.center,
                  color: AppColors.bgBase,
                  child: Text(
                    'No se pudo previsualizar la imagen.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, EvidenceChoice.confirm),
              icon: const Icon(Icons.cloud_upload_outlined, size: 18),
              label: const Text('Enviar evidencia'),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context, EvidenceChoice.replace),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Cambiar foto'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: () => Navigator.pop(context, EvidenceChoice.cancel),
              child: Text('Cancelar',
                  style: TextStyle(color: AppColors.textMuted)),
            ),
          ],
        ),
      ),
    );
  }
}
