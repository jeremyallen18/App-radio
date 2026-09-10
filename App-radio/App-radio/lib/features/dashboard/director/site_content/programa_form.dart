import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/features/dashboard/director/site_content/site_content_api.dart';
import 'package:doliv_social/features/dashboard/director/site_content/site_content_widgets.dart';

/// Crear/editar un programa al aire (tabla `radio_programs`).
/// `item == null` -> crear.
class ProgramaFormScreen extends StatefulWidget {
  const ProgramaFormScreen({super.key, this.item});

  final Map<String, dynamic>? item;

  @override
  State<ProgramaFormScreen> createState() => _ProgramaFormScreenState();
}

class _ProgramaFormScreenState extends State<ProgramaFormScreen> {
  final _api = SiteContentApi('programas');
  final _picker = ImagePicker();

  late final _title = TextEditingController(text: widget.item?['title']?.toString() ?? '');
  late final _modalTitle = TextEditingController(text: widget.item?['modal_title']?.toString() ?? '');
  late final _host = TextEditingController(text: widget.item?['host']?.toString() ?? '');
  late final _schedule = TextEditingController(text: widget.item?['schedule']?.toString() ?? '');
  late final _slotStart = TextEditingController(text: widget.item?['slot_start']?.toString() ?? '');
  late final _slotEnd = TextEditingController(text: widget.item?['slot_end']?.toString() ?? '');
  late final _weekdays = TextEditingController(text: widget.item?['weekdays']?.toString() ?? '');
  late final _badgeIcon = TextEditingController(text: widget.item?['badge_icon']?.toString() ?? '');
  late final _badgeTime = TextEditingController(text: widget.item?['badge_time']?.toString() ?? '');
  late final _badgeLabel = TextEditingController(text: widget.item?['badge_label']?.toString() ?? '');
  late final _accent = TextEditingController(text: widget.item?['accent']?.toString() ?? '');
  late final _icon = TextEditingController(text: widget.item?['icon']?.toString() ?? '');
  late final _categories = TextEditingController(text: widget.item?['categories']?.toString() ?? '');
  late final _cardDesc = TextEditingController(text: widget.item?['card_desc']?.toString() ?? '');
  late final _indexDesc = TextEditingController(text: widget.item?['index_desc']?.toString() ?? '');
  late final _summary = TextEditingController(text: widget.item?['summary']?.toString() ?? '');
  late final _sortOrder = TextEditingController(text: widget.item?['sort_order']?.toString() ?? '0');

  File? _newImage;
  bool _submitting = false;

  bool get _isEditing => widget.item != null;

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    setState(() => _newImage = File(picked.path));
  }

  Future<void> _delete() async {
    final item = widget.item;
    if (item == null) return;
    final confirmed = await confirmSiteDelete(context, _title.text.trim());
    if (!confirmed) return;

    setState(() => _submitting = true);
    try {
      await _api.delete(item['id'].toString());
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _submit() async {
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El título es obligatorio')),
      );
      return;
    }

    setState(() => _submitting = true);
    final fields = {
      'title': _title.text.trim(),
      'modal_title': _modalTitle.text.trim(),
      'host': _host.text.trim(),
      'schedule': _schedule.text.trim(),
      'slot_start': _slotStart.text.trim(),
      'slot_end': _slotEnd.text.trim(),
      'weekdays': _weekdays.text.trim(),
      'badge_icon': _badgeIcon.text.trim(),
      'badge_time': _badgeTime.text.trim(),
      'badge_label': _badgeLabel.text.trim(),
      'accent': _accent.text.trim(),
      'icon': _icon.text.trim(),
      'categories': _categories.text.trim(),
      'card_desc': _cardDesc.text.trim(),
      'index_desc': _indexDesc.text.trim(),
      'summary': _summary.text.trim(),
      'sort_order': _sortOrder.text.trim().isEmpty ? '0' : _sortOrder.text.trim(),
    };

    try {
      if (_isEditing) {
        await _api.update(widget.item!['id'].toString(), fields, imageFile: _newImage);
      } else {
        await _api.create(fields, imageFile: _newImage);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final existingImage = siteImageUrl(widget.item?['image']?.toString());

    return AppScaffold(
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.md),
          SiteFormHeader(
            title: _isEditing ? 'Editar programa' : 'Nuevo programa',
            subtitle: 'Actualiza la información de tu programa',
          ),
          const SizedBox(height: AppSpacing.xl),
          SiteFormField(
            icon: Icons.title,
            label: 'Título',
            required: true,
            controller: _title,
            hintText: 'Ej. Rincón Lunar',
          ),
          const SizedBox(height: AppSpacing.md),
          SiteFormField(
            icon: Icons.web_asset_outlined,
            label: 'Título del modal',
            controller: _modalTitle,
            hintText: 'Título mostrado en el detalle',
          ),
          const SizedBox(height: AppSpacing.md),
          SiteFormField(
            icon: Icons.person_outline,
            label: 'Conductor(a)',
            iconColor: SiteFieldColors.teal,
            controller: _host,
            hintText: 'Nombre del conductor o conductora',
          ),
          const SizedBox(height: AppSpacing.md),
          SiteFormField(
            icon: Icons.schedule_outlined,
            label: 'Horario',
            iconColor: SiteFieldColors.orange,
            controller: _schedule,
            hintText: 'Ej. Lunes a viernes, 4 a 6 pm',
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SiteFormField(
                  icon: Icons.schedule_outlined,
                  label: 'Hora inicio',
                  iconColor: SiteFieldColors.orange,
                  controller: _slotStart,
                  hintText: '0-23',
                  textInputType: TextInputType.number,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: SiteFormField(
                  icon: Icons.schedule_outlined,
                  label: 'Hora fin',
                  iconColor: SiteFieldColors.orange,
                  controller: _slotEnd,
                  hintText: '0-23',
                  textInputType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SiteFormField(
            icon: Icons.view_week_outlined,
            label: 'Días de transmisión',
            controller: _weekdays,
            hintText: 'ISO 1-7 separados por coma (vacío = todos)',
          ),
          const SizedBox(height: AppSpacing.md),
          SiteFormField(
            icon: Icons.label_outline,
            label: 'Ícono de la insignia',
            iconColor: SiteFieldColors.purple,
            controller: _badgeIcon,
            hintText: 'Nombre del ícono',
          ),
          const SizedBox(height: AppSpacing.md),
          SiteFormField(
            icon: Icons.access_time,
            label: 'Hora de la insignia',
            iconColor: SiteFieldColors.purple,
            controller: _badgeTime,
            hintText: 'Texto de la hora',
          ),
          const SizedBox(height: AppSpacing.md),
          SiteFormField(
            icon: Icons.label_outline,
            label: 'Etiqueta de la insignia',
            iconColor: SiteFieldColors.purple,
            controller: _badgeLabel,
            hintText: 'Texto de la etiqueta',
          ),
          const SizedBox(height: AppSpacing.md),
          SiteFormField(
            icon: Icons.palette_outlined,
            label: 'Color de identidad (HEX)',
            iconColor: SiteFieldColors.pink,
            controller: _accent,
            hintText: 'Ej. #3d5afe',
            trailing: SiteColorSwatch(controller: _accent),
          ),
          const SizedBox(height: AppSpacing.md),
          SiteFormField(
            icon: Icons.radio_outlined,
            label: 'Ícono del programa',
            iconColor: SiteFieldColors.green,
            controller: _icon,
            hintText: 'Nombre del ícono',
          ),
          const SizedBox(height: AppSpacing.md),
          SiteFormField(
            icon: Icons.sell_outlined,
            label: 'Categorías',
            iconColor: SiteFieldColors.green,
            controller: _categories,
            hintText: 'Separadas por coma',
          ),
          const SizedBox(height: AppSpacing.md),
          SiteFormField(
            icon: Icons.notes_outlined,
            label: 'Descripción de tarjeta',
            iconColor: SiteFieldColors.orange,
            controller: _cardDesc,
            hintText: 'Descripción corta para la tarjeta',
            maxLines: 3,
          ),
          const SizedBox(height: AppSpacing.md),
          SiteFormField(
            icon: Icons.notes_outlined,
            label: 'Descripción de índice',
            iconColor: SiteFieldColors.orange,
            controller: _indexDesc,
            hintText: 'Descripción corta para el índice',
            maxLines: 3,
          ),
          const SizedBox(height: AppSpacing.md),
          SiteFormField(
            icon: Icons.menu_book_outlined,
            label: 'Resumen',
            iconColor: SiteFieldColors.purple,
            controller: _summary,
            hintText: 'Resumen del programa',
            maxLines: 4,
          ),
          const SizedBox(height: AppSpacing.md),
          SiteFormField(
            icon: Icons.swap_vert,
            label: 'Orden de aparición',
            controller: _sortOrder,
            hintText: 'Ej. 1',
            textInputType: TextInputType.number,
          ),
          const SizedBox(height: AppSpacing.md),
          SiteImagePickerField(
            newImage: _newImage,
            existingImageUrl: existingImage,
            onPick: _pickImage,
            title: 'Imagen del programa',
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: _submitting ? 'Guardando…' : 'Guardar',
            loading: _submitting,
            onPressed: _submitting ? null : _submit,
          ),
          if (_isEditing) ...[
            const SizedBox(height: AppSpacing.md),
            SiteDeleteButton(
              label: 'Eliminar programa',
              onPressed: _submitting ? null : _delete,
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}
