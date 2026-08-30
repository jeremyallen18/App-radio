import 'dart:io';

import 'package:flutter/material.dart';

import 'package:doliv_social/design/design.dart';

/// Paleta de colores de ícono para las tarjetas de campo — cada tipo de dato
/// (texto, fecha, color, número...) usa un color distinto para que el ojo
/// escanee el formulario más rápido, igual que en el resto de la app.
class SiteFieldColors {
  SiteFieldColors._();

  static const blue = AppColors.accent;
  static const green = AppColors.success;
  static const purple = Color(0xFF9B7FE8);
  static const orange = AppColors.warning;
  static const pink = Color(0xFFE86BA0);
  static const teal = Color(0xFF4DC7C7);
  static const red = AppColors.error;
  static const whatsapp = Color(0xFF25D366);
}

/// Header propio de los formularios de contenido del sitio: botón volver +
/// título + subtítulo, en vez de un `AppBar` genérico. Sustituye al
/// `AppBar` para que el formulario se sienta como una pantalla dedicada
/// (igual en Android/iOS/escritorio, sin depender del back nativo).
class SiteFormHeader extends StatelessWidget {
  const SiteFormHeader({super.key, required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Material(
          color: AppColors.surface,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => Navigator.of(context).maybePop(),
            child: const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Icon(Icons.arrow_back, color: AppColors.textPrimary, size: 20),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 24,
                ),
              ),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Campo de formulario con ícono identificador, etiqueta y entrada de texto,
/// todo dentro de una tarjeta que resalta con un borde de acento al recibir
/// foco — reemplaza al `AppTextField` suelto con solo un hint como única
/// pista de qué se está editando.
class SiteFormField extends StatefulWidget {
  const SiteFormField({
    super.key,
    required this.icon,
    required this.label,
    this.iconColor = SiteFieldColors.blue,
    this.required = false,
    this.controller,
    this.hintText,
    this.helperText,
    this.maxLines = 1,
    this.maxLength,
    this.textInputType,
    this.readOnly = false,
    this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final Color iconColor;
  final bool required;
  final TextEditingController? controller;
  final String? hintText;
  final String? helperText;
  final int maxLines;
  final int? maxLength;
  final TextInputType? textInputType;
  final bool readOnly;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  State<SiteFormField> createState() => _SiteFormFieldState();
}

class _SiteFormFieldState extends State<SiteFormField> {
  final _focusNode = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => setState(() => _focused = _focusNode.hasFocus));
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: _focused ? AppColors.accentStrong : AppColors.surfaceBorder,
          width: _focused ? 1.5 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: widget.iconColor.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(AppRadius.chip),
            ),
            child: Icon(widget.icon, color: widget.iconColor, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      color: _focused ? AppColors.accentStrong : AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                    children: [
                      TextSpan(text: widget.label),
                      if (widget.required)
                        const TextSpan(text: ' *', style: TextStyle(color: AppColors.error)),
                    ],
                  ),
                ),
                TextFormField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, height: 1.4),
                  cursorColor: AppColors.textPrimary,
                  keyboardType: widget.textInputType,
                  maxLines: widget.maxLines,
                  maxLength: widget.maxLength,
                  readOnly: widget.readOnly,
                  onTap: widget.onTap,
                  decoration: InputDecoration(
                    isDense: true,
                    isCollapsed: false,
                    filled: false,
                    hintText: widget.hintText,
                    hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
                    contentPadding: const EdgeInsets.only(top: 4),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    counterStyle: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
                ),
                if (widget.helperText != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    widget.helperText!,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
          if (widget.trailing != null) ...[
            const SizedBox(width: AppSpacing.sm),
            widget.trailing!,
          ],
        ],
      ),
    );
  }
}

/// Interpreta un color hex (`#RRGGBB` o `RRGGBB`) escrito a mano; `null` si
/// todavía no es un hex válido.
Color? parseHexColor(String hex) {
  var h = hex.trim();
  if (h.isEmpty) return null;
  if (h.startsWith('#')) h = h.substring(1);
  if (h.length == 6) h = 'FF$h';
  if (h.length != 8) return null;
  final value = int.tryParse(h, radix: 16);
  if (value == null) return null;
  return Color(value);
}

/// Pastilla circular que previsualiza en vivo el color hex escrito en
/// [controller] — se usa como `trailing` de un [SiteFormField] de color.
class SiteColorSwatch extends StatelessWidget {
  const SiteColorSwatch({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final color = parseHexColor(controller.text);
        return Container(
          width: 28,
          height: 28,
          margin: const EdgeInsets.only(top: 24),
          decoration: BoxDecoration(
            color: color ?? AppColors.bgBase,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.surfaceBorder, width: 1.5),
          ),
        );
      },
    );
  }
}

/// Dibuja un borde punteado alrededor de un rectángulo redondeado — usado
/// por [SiteImagePickerField] para distinguir la zona de subida de imagen
/// del resto de campos del formulario.
class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius));
    final path = Path()..addRRect(rrect);
    final dashed = Path();
    const dashWidth = 6.0;
    const dashSpace = 4.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        dashed.addPath(metric.extractPath(distance, next.clamp(0, metric.length)), Offset.zero);
        distance = next + dashSpace;
      }
    }
    canvas.drawPath(
      dashed,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

/// Selector de imagen compartido por los 7 formularios de contenido del
/// sitio: muestra la nueva imagen elegida o, si no hay ninguna, la que ya
/// está guardada (o un placeholder si el registro es nuevo).
class SiteImagePickerField extends StatelessWidget {
  const SiteImagePickerField({
    super.key,
    required this.newImage,
    required this.existingImageUrl,
    required this.onPick,
    this.title = 'Imagen',
    this.aspectHint = '1:1 (cuadrada)',
  });

  final File? newImage;
  final String? existingImageUrl;
  final VoidCallback onPick;

  /// Título completo mostrado sobre el estado del campo (ej. "Imagen del
  /// servicio", "Imagen del integrante").
  final String title;
  final String aspectHint;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: CustomPaint(
        painter: _DashedBorderPainter(color: AppColors.surfaceBorder, radius: AppRadius.card),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      newImage != null
                          ? 'Nueva imagen seleccionada'
                          : existingImageUrl != null
                              ? 'Toca para cambiar la imagen'
                              : 'Toca para elegir una imagen',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Recomendado: $aspectHint',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: SiteFieldColors.blue.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                ),
                child: const Icon(Icons.add_photo_alternate_outlined, color: SiteFieldColors.blue, size: 20),
              ),
            ],
          ),
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

/// Título de sección dentro de un formulario largo (ej. "Redes sociales",
/// "Episodios"), consistente con el resto de la jerarquía tipográfica.
class SiteFormSectionTitle extends StatelessWidget {
  const SiteFormSectionTitle(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 15),
    );
  }
}

/// Diálogo de confirmación reutilizado por los 7 formularios para el botón
/// "Eliminar" del pie de página.
Future<bool> confirmSiteDelete(BuildContext context, String label) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('¿Eliminar este elemento?'),
      content: Text(label),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Eliminar', style: TextStyle(color: AppColors.error)),
        ),
      ],
    ),
  );
  return confirmed == true;
}

/// Botón "Eliminar ..." del pie del formulario, visible solo al editar un
/// registro existente.
class SiteDeleteButton extends StatelessWidget {
  const SiteDeleteButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 18),
        label: Text(label, style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
