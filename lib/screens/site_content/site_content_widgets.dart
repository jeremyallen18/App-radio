import 'dart:io';

import 'package:flutter/material.dart';

import '../../design/design.dart';

/// Selector de imagen compartido por los 7 formularios de contenido del
/// sitio: muestra la nueva imagen elegida o, si no hay ninguna, la que ya
/// está guardada (o un placeholder si el registro es nuevo).
class SiteImagePickerField extends StatelessWidget {
  const SiteImagePickerField({
    super.key,
    required this.newImage,
    required this.existingImageUrl,
    required this.onPick,
  });

  final File? newImage;
  final String? existingImageUrl;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.chip),
              child: newImage != null
                  ? Image.file(newImage!, width: 56, height: 56, fit: BoxFit.cover)
                  : existingImageUrl != null
                      ? Image.network(existingImageUrl!, width: 56, height: 56, fit: BoxFit.cover)
                      : Container(
                          width: 56,
                          height: 56,
                          color: AppColors.bgBase,
                          child: const Icon(Icons.image_outlined, color: AppColors.textMuted),
                        ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                newImage != null
                    ? 'Nueva imagen seleccionada'
                    : existingImageUrl != null
                        ? 'Toca para cambiar la imagen'
                        : 'Toca para elegir una imagen',
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
              ),
            ),
            const Icon(Icons.photo_library_outlined, color: AppColors.accent),
          ],
        ),
      ),
    );
  }
}

/// Fila editable para las listas repetibles (redes sociales de un
/// patrocinador, episodios de un podcast): 2 o 3 campos de texto en línea
/// más un botón para quitar la fila.
class SiteRepeatRow extends StatelessWidget {
  const SiteRepeatRow({super.key, required this.controllers, required this.hints, required this.onRemove});

  final List<TextEditingController> controllers;
  final List<String> hints;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (int i = 0; i < controllers.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: AppTextField(controller: controllers[i], hintText: hints[i]),
            ),
          ],
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.error, size: 18),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}
