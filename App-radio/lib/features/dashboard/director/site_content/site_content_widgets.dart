import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import 'package:doliv_social/design/design.dart';

/// Paleta de colores de ícono para las tarjetas de campo — cada tipo de dato
/// (texto, fecha, color, número...) usa un color distinto para que el ojo
/// escanee el formulario más rápido, igual que en el resto de la app.
class SiteFieldColors {
  SiteFieldColors._();

  // `blue/green/orange/red` dependen del modo (claro/oscuro), así que son
  // getters que se resuelven en cada uso; el resto son literales fijos.
  static Color get blue => AppColors.accent;
  static Color get green => AppColors.success;
  static const Color purple = Color(0xFF9B7FE8);
  static Color get orange => AppColors.warning;
  static const Color pink = Color(0xFFE86BA0);
  static const Color teal = Color(0xFF4DC7C7);
  static Color get red => AppColors.error;
  static const Color whatsapp = Color(0xFF25D366);
}

/// Header propio de los formularios de contenido del sitio: botón volver +
/// título + subtítulo, en vez de un `AppBar` genérico. Sustituye al
/// `AppBar` para que el formulario se sienta como una pantalla dedicada
/// (igual en Android/iOS/escritorio, sin depender del back nativo).
class SiteFormHeader extends StatelessWidget {
  const SiteFormHeader(
      {super.key, required this.title, required this.subtitle});

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
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Icon(Icons.arrow_back,
                  color: AppColors.textPrimary, size: 20),
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
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 24,
                ),
              ),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
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
    this.iconColor,
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

  /// Si es null, usa [SiteFieldColors.blue].
  final Color? iconColor;
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
    _focusNode
        .addListener(() => setState(() => _focused = _focusNode.hasFocus));
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = widget.iconColor ?? SiteFieldColors.blue;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
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
              color: iconColor.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(AppRadius.chip),
            ),
            child: Icon(widget.icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      color: _focused
                          ? AppColors.accentStrong
                          : AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                    children: [
                      TextSpan(text: widget.label),
                      if (widget.required)
                        TextSpan(
                            text: ' *',
                            style: TextStyle(color: AppColors.error)),
                    ],
                  ),
                ),
                TextFormField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  style: TextStyle(
                      color: AppColors.textPrimary, fontSize: 14, height: 1.4),
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
                    hintStyle:
                        TextStyle(color: AppColors.textMuted, fontSize: 14),
                    contentPadding: const EdgeInsets.only(top: 4),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    counterStyle:
                        TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
                ),
                if (widget.helperText != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    widget.helperText!,
                    style: TextStyle(color: AppColors.textMuted, fontSize: 11),
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
    final rrect =
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius));
    final path = Path()..addRRect(rrect);
    final dashed = Path();
    const dashWidth = 6.0;
    const dashSpace = 4.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        dashed.addPath(
            metric.extractPath(distance, next.clamp(0, metric.length)),
            Offset.zero);
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

  /// Contenido de la miniatura (56×56): la imagen nueva elegida, la ya
  /// guardada, o un placeholder. Tanto `Image.file` como `Image.network`
  /// llevan `errorBuilder` para que un archivo borrado o una URL 404 caigan
  /// en el mismo placeholder en vez de un `ErrorWidget` a tamaño natural.
  Widget _thumb() {
    if (newImage != null) {
      return Image.file(
        newImage!,
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _thumbPlaceholder(),
      );
    }
    if (existingImageUrl != null) {
      return Image.network(
        existingImageUrl!,
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _thumbPlaceholder(),
      );
    }
    return _thumbPlaceholder();
  }

  Widget _thumbPlaceholder() => Container(
        width: 56,
        height: 56,
        color: AppColors.bgBase,
        child: Icon(Icons.image_outlined, color: AppColors.textMuted),
      );

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: CustomPaint(
        painter: _DashedBorderPainter(
            color: AppColors.surfaceBorder, radius: AppRadius.card),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              // Miniatura SIEMPRE de 56×56: `ClipRRect` recorta el pixel pero
              // no acota el layout, así que el `SizedBox` es lo que impide que
              // un `ErrorWidget` (imagen 404 sin `errorBuilder`) reviente la
              // fila. Ver overflow de 747 px en site_content_widgets.dart:326.
              SizedBox(
                width: 56,
                height: 56,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                  child: _thumb(),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      newImage != null
                          ? 'Archivo listo para subir'
                          : existingImageUrl != null
                              ? 'Toca para reemplazar la imagen'
                              : 'Toca para cargar una imagen',
                      style:
                          TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Recomendado: $aspectHint',
                      style:
                          TextStyle(color: AppColors.textMuted, fontSize: 11),
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
                child: Icon(Icons.add_photo_alternate_outlined,
                    color: SiteFieldColors.blue, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Selector de fecha de solo lectura que abre el calendario nativo y conserva
/// en el controlador el formato ISO que espera el API.
class SiteDatePickerField extends StatelessWidget {
  const SiteDatePickerField({
    super.key,
    required this.controller,
    required this.label,
    this.hintText,
    this.iconColor,
    this.firstDate,
    this.lastDate,
  });

  final TextEditingController controller;
  final String label;
  final String? hintText;
  final Color? iconColor;
  final DateTime? firstDate;
  final DateTime? lastDate;

  DateTime _initialDate() {
    return DateTime.tryParse(controller.text.trim()) ?? DateTime.now();
  }

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final minimum = firstDate ?? now.subtract(const Duration(days: 365));
    final maximum = lastDate ?? DateTime(now.year + 5);
    final initial = _initialDate();
    final safeInitial = initial.isBefore(minimum)
        ? minimum
        : initial.isAfter(maximum)
            ? maximum
            : initial;
    final selected = await showDatePicker(
      context: context,
      initialDate: safeInitial,
      firstDate: minimum,
      lastDate: maximum,
    );
    if (selected == null) return;
    controller.text =
        '${selected.year}-${selected.month.toString().padLeft(2, '0')}-${selected.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return SiteFormField(
      icon: Icons.calendar_month_outlined,
      iconColor: iconColor ?? SiteFieldColors.teal,
      label: label,
      controller: controller,
      hintText: hintText ?? 'Toca para elegir una fecha',
      readOnly: true,
      onTap: () => _pick(context),
      trailing: Icon(Icons.expand_more, color: AppColors.textMuted),
    );
  }
}

/// Selector de hora nativo. Guarda una etiqueta legible en formato de 24 horas
/// para que se use directamente en los campos de horario del sitio.
class SiteTimePickerField extends StatelessWidget {
  const SiteTimePickerField({
    super.key,
    required this.controller,
    required this.label,
    this.hintText,
    this.iconColor,
    this.storeHourOnly = false,
  });

  final TextEditingController controller;
  final String label;
  final String? hintText;
  final Color? iconColor;
  final bool storeHourOnly;

  TimeOfDay _initialTime() {
    final match =
        RegExp(r'^(\d{1,2})(?::(\d{2}))?').firstMatch(controller.text);
    final hour = int.tryParse(match?.group(1) ?? '');
    final minute = int.tryParse(match?.group(2) ?? '') ?? 0;
    if (hour == null || hour > 23 || minute > 59) return TimeOfDay.now();
    return TimeOfDay(hour: hour, minute: minute);
  }

  Future<void> _pick(BuildContext context) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _initialTime(),
    );
    if (selected == null) return;
    controller.text = storeHourOnly
        ? selected.hour.toString()
        : '${selected.hour.toString().padLeft(2, '0')}:${selected.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return SiteFormField(
      icon: Icons.access_time_outlined,
      iconColor: iconColor ?? SiteFieldColors.orange,
      label: label,
      controller: controller,
      hintText: hintText ?? 'Toca para elegir la hora',
      readOnly: true,
      onTap: () => _pick(context),
      trailing: Icon(Icons.expand_more, color: AppColors.textMuted),
    );
  }
}

/// Selección de días de la semana que guarda el contrato ISO del backend
/// (1=lunes ... 7=domingo). Sin selección significa todos los días.
class SiteWeekdayPickerField extends StatefulWidget {
  const SiteWeekdayPickerField({super.key, required this.controller});

  final TextEditingController controller;

  @override
  State<SiteWeekdayPickerField> createState() => _SiteWeekdayPickerFieldState();
}

class _SiteWeekdayPickerFieldState extends State<SiteWeekdayPickerField> {
  static const _days = [
    (value: 1, label: 'L'),
    (value: 2, label: 'M'),
    (value: 3, label: 'X'),
    (value: 4, label: 'J'),
    (value: 5, label: 'V'),
    (value: 6, label: 'S'),
    (value: 7, label: 'D'),
  ];

  late Set<int> _selected = _readDays();

  Set<int> _readDays() => widget.controller.text
      .split(',')
      .map(int.tryParse)
      .whereType<int>()
      .where((day) => day >= 1 && day <= 7)
      .toSet();

  void _save() {
    final values = _selected.toList()..sort();
    widget.controller.text = values.join(',');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: SiteFieldColors.blue.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                ),
                child: Icon(
                  Icons.calendar_view_week_outlined,
                  color: SiteFieldColors.blue,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              const Expanded(
                child: Text(
                  'Días de transmisión',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() => _selected.clear());
                  _save();
                },
                child: const Text('Todos'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _selected.isEmpty
                ? 'Se transmite todos los días.'
                : 'Selecciona los días en que se transmite.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: _days.map((day) {
              final selected = _selected.contains(day.value);
              return ChoiceChip(
                label: Text(day.label),
                selected: selected,
                onSelected: (_) {
                  setState(() {
                    selected
                        ? _selected.remove(day.value)
                        : _selected.add(day.value);
                  });
                  _save();
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

/// Una opción de [SiteChoiceChipsField]: valor que se envía al backend +
/// etiqueta legible para mostrar.
class SiteChoiceOption {
  const SiteChoiceOption(this.value, this.label);

  final String value;
  final String label;
}

/// Selector de una sola opción entre pocas alternativas fijas (p. ej. la
/// categoría de un integrante de Equipo), mostradas como chips — mismo
/// patrón visual que [SiteWeekdayPickerField] pero de selección única y sin
/// controller (el valor vive en el estado del formulario dueño).
class SiteChoiceChipsField extends StatelessWidget {
  const SiteChoiceChipsField({
    super.key,
    required this.icon,
    required this.label,
    this.iconColor,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final Color? iconColor;
  final List<SiteChoiceOption> options;
  final String? value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? SiteFieldColors.teal;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(label,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: options.map((option) {
              final selected = option.value == value;
              return ChoiceChip(
                label: Text(option.label),
                selected: selected,
                onSelected: (_) => onChanged(option.value),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

/// Campo de color de identidad: pastilla que previsualiza el hex actual del
/// [controller] y, al tocarla, abre una rueda de color (HSV) para elegir
/// cualquier tono sin escribir el código a mano. Escribe el hex resultante
/// de vuelta en el controller, igual que si el usuario lo hubiera tecleado.
class SiteColorWheelField extends StatefulWidget {
  const SiteColorWheelField({
    super.key,
    required this.icon,
    required this.label,
    this.iconColor,
    required this.controller,
  });

  final IconData icon;
  final String label;
  final Color? iconColor;
  final TextEditingController controller;

  @override
  State<SiteColorWheelField> createState() => _SiteColorWheelFieldState();
}

class _SiteColorWheelFieldState extends State<SiteColorWheelField> {
  Future<void> _openPicker() async {
    var pickedColor = parseHexColor(widget.controller.text) ?? SiteFieldColors.teal;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Elige un color'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: pickedColor,
            onColorChanged: (color) => pickedColor = color,
            paletteType: PaletteType.hueWheel,
            enableAlpha: false,
            labelTypes: const [],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Listo'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      setState(() {
        widget.controller.text =
            '#${pickedColor.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.iconColor ?? SiteFieldColors.teal;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(AppRadius.chip),
            ),
            child: Icon(widget.icon, color: color),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(widget.label,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          AnimatedBuilder(
            animation: widget.controller,
            builder: (context, _) {
              final swatch = parseHexColor(widget.controller.text);
              return GestureDetector(
                onTap: _openPicker,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: swatch ?? AppColors.bgBase,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.surfaceBorder, width: 1.5),
                  ),
                  child: swatch == null
                      ? const Icon(Icons.colorize, size: 18)
                      : null,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Campo de etiquetas: escribe texto y presiona Enter (o el botón +) para
/// agregarlo como chip removible. Guarda el texto en [controller] con el
/// mismo formato "una por línea" que ya espera el backend (p. ej.
/// `site_equipo_text('interests')`), así que no requiere cambios ahí.
class SiteTagInputField extends StatefulWidget {
  const SiteTagInputField({
    super.key,
    required this.icon,
    required this.label,
    this.iconColor,
    required this.controller,
    this.hintText,
  });

  final IconData icon;
  final String label;
  final Color? iconColor;
  final TextEditingController controller;
  final String? hintText;

  @override
  State<SiteTagInputField> createState() => _SiteTagInputFieldState();
}

class _SiteTagInputFieldState extends State<SiteTagInputField> {
  final _inputController = TextEditingController();
  final List<String> _tags = [];

  @override
  void initState() {
    super.initState();
    _tags.addAll(widget.controller.text
        .split('\n')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty));
  }

  void _save() {
    widget.controller.text = _tags.join('\n');
  }

  void _addTag() {
    final tag = _inputController.text.trim();
    if (tag.isEmpty) return;
    setState(() {
      if (!_tags.contains(tag)) _tags.add(tag);
      _inputController.clear();
    });
    _save();
  }

  void _removeTag(String tag) {
    setState(() => _tags.remove(tag));
    _save();
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.iconColor ?? SiteFieldColors.teal;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                ),
                child: Icon(widget.icon, color: color),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(widget.label,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _inputController,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: widget.hintText ?? 'Escribe un interés y presiona +',
                  ),
                  onSubmitted: (_) => _addTag(),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              IconButton.filled(
                onPressed: _addTag,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          if (_tags.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: _tags.map((tag) {
                return Chip(
                  label: Text(tag),
                  onDeleted: () => _removeTag(tag),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

/// Una opción seleccionable de otro registro del sitio (p. ej. un integrante
/// de `radio_team` o un `radio_programs`) para los selectores de vínculo.
class SiteLinkOption {
  const SiteLinkOption({required this.id, required this.label, this.subtitle});

  final int id;
  final String label;
  final String? subtitle;
}

/// Valor centinela que representa "quitar el vínculo actual" al volver del
/// bottom sheet de [SiteLinkPickerField] — se distingue por identidad, no
/// por id, porque -1 podría ser un id real en teoría.
const SiteLinkOption _siteUnlinkOption = SiteLinkOption(id: -1, label: '');

/// Campo para vincular este registro con OTRO ya existente en el sitio — por
/// ejemplo, el integrante real de Equipo que conduce un programa. A
/// diferencia de escribir el nombre a mano, aquí se elige de una lista real
/// cargada del backend, así el vínculo sigue siendo válido aunque el nombre
/// del integrante cambie después.
class SiteLinkPickerField extends StatelessWidget {
  const SiteLinkPickerField({
    super.key,
    required this.icon,
    required this.label,
    this.iconColor,
    required this.optionsLoader,
    required this.selectedId,
    required this.selectedLabel,
    required this.onSelected,
    this.placeholder = 'Sin vincular · toca para elegir',
    this.emptyMessage = 'Todavía no hay registros para vincular.',
  });

  final IconData icon;
  final String label;
  final Color? iconColor;

  /// Se llama cada vez que se abre el selector, para traer la lista más
  /// reciente (los registros pueden haberse creado hace apenas un momento).
  final Future<List<SiteLinkOption>> Function() optionsLoader;
  final int? selectedId;
  final String? selectedLabel;
  final ValueChanged<SiteLinkOption?> onSelected;
  final String placeholder;
  final String emptyMessage;

  Future<void> _openPicker(BuildContext context) async {
    List<SiteLinkOption> options;
    try {
      options = await optionsLoader();
    } catch (_) {
      options = const [];
    }
    if (!context.mounted) return;
    final chosen = await showModalBottomSheet<SiteLinkOption>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
      ),
      builder: (_) => _SiteLinkPickerSheet(
        title: label,
        options: options,
        selectedId: selectedId,
        emptyMessage: emptyMessage,
      ),
    );
    if (chosen == null) return;
    onSelected(identical(chosen, _siteUnlinkOption) ? null : chosen);
  }

  @override
  Widget build(BuildContext context) {
    final hasLink = selectedId != null;
    final color = iconColor ?? SiteFieldColors.teal;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: () => _openPicker(context),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
              color: hasLink ? color : AppColors.surfaceBorder,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(
                      hasLink ? (selectedLabel ?? '') : placeholder,
                      style: TextStyle(
                        color:
                            hasLink ? AppColors.textPrimary : AppColors.textMuted,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (hasLink)
                IconButton(
                  icon: Icon(Icons.link_off, color: AppColors.textMuted),
                  tooltip: 'Quitar vínculo',
                  onPressed: () => onSelected(null),
                )
              else
                Icon(Icons.expand_more, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _SiteLinkPickerSheet extends StatefulWidget {
  const _SiteLinkPickerSheet({
    required this.title,
    required this.options,
    required this.selectedId,
    required this.emptyMessage,
  });

  final String title;
  final List<SiteLinkOption> options;
  final int? selectedId;
  final String emptyMessage;

  @override
  State<_SiteLinkPickerSheet> createState() => _SiteLinkPickerSheetState();
}

class _SiteLinkPickerSheetState extends State<_SiteLinkPickerSheet> {
  final _search = TextEditingController();
  late List<SiteLinkOption> _filtered = widget.options;

  void _filter(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? widget.options
          : widget.options
              .where((o) => o.label.toLowerCase().contains(q))
              .toList();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.lg,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Vincular · ${widget.title}',
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: AppSpacing.md),
            if (widget.options.length > 5) ...[
              TextField(
                controller: _search,
                onChanged: _filter,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Buscar…',
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                    borderSide: BorderSide(color: AppColors.surfaceBorder),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            Flexible(
              child: widget.options.isEmpty
                  ? Padding(
                      padding:
                          const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                      child: Text(widget.emptyMessage,
                          style: TextStyle(color: AppColors.textMuted)),
                    )
                  : ListView(
                      shrinkWrap: true,
                      children: [
                        if (widget.selectedId != null)
                          ListTile(
                            leading: Icon(Icons.link_off,
                                color: AppColors.error),
                            title: Text('Quitar vínculo',
                                style: TextStyle(color: AppColors.error)),
                            onTap: () =>
                                Navigator.of(context).pop(_siteUnlinkOption),
                          ),
                        ..._filtered.map((option) => ListTile(
                              leading: Icon(
                                option.id == widget.selectedId
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_unchecked,
                                color: option.id == widget.selectedId
                                    ? SiteFieldColors.teal
                                    : AppColors.textMuted,
                              ),
                              title: Text(option.label),
                              subtitle: option.subtitle != null
                                  ? Text(option.subtitle!)
                                  : null,
                              onTap: () => Navigator.of(context).pop(option),
                            )),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Selección múltiple de registros vinculados (p. ej. los programas que
/// conduce un integrante del equipo). A diferencia de [SiteLinkPickerField],
/// puede marcar varias opciones a la vez mediante chips.
class SiteMultiLinkPickerField extends StatelessWidget {
  const SiteMultiLinkPickerField({
    super.key,
    required this.icon,
    required this.label,
    this.iconColor,
    required this.options,
    required this.selectedIds,
    required this.onChanged,
    this.helperText,
    this.emptyMessage = 'Todavía no hay registros para vincular.',
  });

  final IconData icon;
  final String label;
  final Color? iconColor;
  final List<SiteLinkOption> options;
  final Set<int> selectedIds;
  final ValueChanged<Set<int>> onChanged;
  final String? helperText;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? SiteFieldColors.teal;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(label,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              if (selectedIds.isNotEmpty)
                TextButton(
                  onPressed: () => onChanged(const {}),
                  child: const Text('Quitar todos'),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            helperText ??
                (selectedIds.isEmpty
                    ? 'No conduce ningún programa todavía.'
                    : 'Conduce ${selectedIds.length} programa(s).'),
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (options.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Text(emptyMessage,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            )
          else
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: options.map((option) {
                final selected = selectedIds.contains(option.id);
                return FilterChip(
                  label: Text(option.label),
                  selected: selected,
                  onSelected: (value) {
                    final updated = Set<int>.from(selectedIds);
                    value ? updated.add(option.id) : updated.remove(option.id);
                    onChanged(updated);
                  },
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

/// Fila editable para las listas repetibles (redes sociales de un
/// patrocinador, episodios de un podcast): 2 o 3 campos de texto en línea
/// más un botón para quitar la fila.
class SiteRepeatRow extends StatelessWidget {
  const SiteRepeatRow(
      {super.key,
      required this.controllers,
      required this.hints,
      required this.onRemove});

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
              child:
                  AppTextField(controller: controllers[i], hintText: hints[i]),
            ),
          ],
          IconButton(
            icon: Icon(Icons.close, color: AppColors.error, size: 18),
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
      style: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 15),
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
          child: Text('Eliminar', style: TextStyle(color: AppColors.error)),
        ),
      ],
    ),
  );
  return confirmed == true;
}

/// Botón "Eliminar ..." del pie del formulario, visible solo al editar un
/// registro existente.
class SiteDeleteButton extends StatelessWidget {
  const SiteDeleteButton(
      {super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(Icons.delete_outline, color: AppColors.error, size: 18),
        label: Text(label,
            style:
                TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
