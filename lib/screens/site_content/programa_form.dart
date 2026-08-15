import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../design/design.dart';
import 'site_content_api.dart';
import 'site_content_widgets.dart';

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
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar programa' : 'Nuevo programa'),
        leading: AppBackButton.leadingFor(context),
        automaticallyImplyLeading: false,
      ),
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.lg),
          AppTextField(controller: _title, hintText: 'Título *'),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(controller: _modalTitle, hintText: 'Título del modal'),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(controller: _host, hintText: 'Conductor(a)'),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(controller: _schedule, hintText: 'Horario (texto)'),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: _slotStart,
                  hintText: 'Hora inicio (0-23)',
                  textInputType: TextInputType.number,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppTextField(
                  controller: _slotEnd,
                  hintText: 'Hora fin (0-23)',
                  textInputType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(controller: _weekdays, hintText: 'Días ISO 1-7 separados por coma (vacío = todos)'),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(controller: _badgeIcon, hintText: 'Ícono de la insignia'),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(controller: _badgeTime, hintText: 'Hora de la insignia (texto)'),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(controller: _badgeLabel, hintText: 'Etiqueta de la insignia'),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(controller: _accent, hintText: 'Color de identidad (hex)'),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(controller: _icon, hintText: 'Ícono del programa'),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(controller: _categories, hintText: 'Categorías (separadas por coma)'),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(controller: _cardDesc, hintText: 'Descripción de tarjeta', maxLines: 3),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(controller: _indexDesc, hintText: 'Descripción de índice', maxLines: 3),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(controller: _summary, hintText: 'Resumen', maxLines: 4),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            controller: _sortOrder,
            hintText: 'Orden de aparición',
            textInputType: TextInputType.number,
          ),
          const SizedBox(height: AppSpacing.lg),
          SiteImagePickerField(newImage: _newImage, existingImageUrl: existingImage, onPick: _pickImage),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: _submitting ? 'Guardando…' : 'Guardar',
            loading: _submitting,
            onPressed: _submitting ? null : _submit,
          ),
        ],
      ),
    );
  }
}
