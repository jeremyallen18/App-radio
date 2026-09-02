import 'package:flutter/material.dart';
import '../design/design.dart';

/// Encabezado reutilizado por todas las pantallas internas de Resource
/// Manager (Documentación, Descargar/Publicar recursos, Documentos,
/// Asistencia para líderes, Recursos de imágenes): botón de volver, título
/// y una línea de subtítulo opcional, con el mismo estilo que ya usaba
/// `Resources.dart`. Antes cada pantalla tenía su propio `AppBar` (o
/// ninguno) con colores y tamaños distintos entre sí.
class ResourceHeader extends StatelessWidget {
  const ResourceHeader({super.key, required this.title, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Row(
          children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
            ),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(left: 56, right: AppSpacing.lg, top: 4),
            child: Text(
              subtitle!,
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}
