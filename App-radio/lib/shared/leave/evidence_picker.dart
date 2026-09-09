import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:doliv_social/design/design.dart';

/// Selector de evidencia (foto) reutilizable por el formulario de permisos y
/// por la justificación de faltas. Muestra una vista previa cuando ya hay
/// archivo y un botón para elegir/cambiar. La subida real la hace quien lo
/// usa (multipart), aquí solo se elige el [File].
class EvidencePicker extends StatelessWidget {
  const EvidencePicker({super.key, required this.file, required this.onPicked});

  final File? file;
  final ValueChanged<File> onPicked;

  Future<void> _pick(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading:
                  Icon(Icons.photo_camera_outlined, color: AppColors.accent),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading:
                  Icon(Icons.photo_library_outlined, color: AppColors.accent),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final x = await ImagePicker()
        .pickImage(source: source, imageQuality: 85, maxWidth: 2000);
    if (x == null) return;
    onPicked(File(x.path));
  }

  @override
  Widget build(BuildContext context) {
    final f = file;
    if (f != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.card),
            child: Image.file(f,
                height: 180, width: double.infinity, fit: BoxFit.cover),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton.icon(
            onPressed: () => _pick(context),
            icon: const Icon(Icons.refresh),
            label: const Text('Cambiar evidencia'),
          ),
        ],
      );
    }
    return OutlinedButton.icon(
      onPressed: () => _pick(context),
      icon: const Icon(Icons.photo_camera_outlined),
      label: const Text('AGREGAR EVIDENCIA'),
    );
  }
}
