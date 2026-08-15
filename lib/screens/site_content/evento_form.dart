import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../design/design.dart';
import 'site_content_api.dart';
import 'site_content_widgets.dart';

/// Crear/editar un evento (tabla `radio_events`). `item == null` -> crear.
class EventoFormScreen extends StatefulWidget {
  const EventoFormScreen({super.key, this.item});

  final Map<String, dynamic>? item;

  @override
  State<EventoFormScreen> createState() => _EventoFormScreenState();
}

class _EventoFormScreenState extends State<EventoFormScreen> {
  final _api = SiteContentApi('eventos');
  final _picker = ImagePicker();

  late final _title = TextEditingController(text: widget.item?['title']?.toString() ?? '');
  late final _artist = TextEditingController(text: widget.item?['artist']?.toString() ?? '');
  late final _location = TextEditingController(text: widget.item?['location']?.toString() ?? '');
  late final _eventDate = TextEditingController(text: widget.item?['event_date']?.toString() ?? '');
  late final _weekday = TextEditingController(text: widget.item?['weekday']?.toString() ?? '');
  late final _day = TextEditingController(text: widget.item?['day']?.toString() ?? '');
  late final _month = TextEditingController(text: widget.item?['month']?.toString() ?? '');
  late final _year = TextEditingController(text: widget.item?['year']?.toString() ?? '');
  late final _timeLabel = TextEditingController(text: widget.item?['time_label']?.toString() ?? '');
  late final _description = TextEditingController(text: widget.item?['description']?.toString() ?? '');
  late final _sortOrder = TextEditingController(text: widget.item?['sort_order']?.toString() ?? '0');

  File? _newImage;
  bool _submitting = false;

  bool get _isEditing => widget.item != null;

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    setState(() => _newImage = File(picked.path));
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null) return;
    setState(() {
      _eventDate.text =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    });
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
      'artist': _artist.text.trim(),
      'location': _location.text.trim(),
      'event_date': _eventDate.text.trim(),
      'weekday': _weekday.text.trim(),
      'day': _day.text.trim(),
      'month': _month.text.trim(),
      'year': _year.text.trim(),
      'time_label': _timeLabel.text.trim(),
      'description': _description.text.trim(),
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
        title: Text(_isEditing ? 'Editar evento' : 'Nuevo evento'),
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
          AppTextField(controller: _artist, hintText: 'Artista / presentador'),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(controller: _location, hintText: 'Lugar'),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            controller: _eventDate,
            hintText: 'Fecha del evento (vacío = "Próximamente")',
            readOnly: true,
            onTap: _pickDate,
            prefixIcon: const Icon(Icons.calendar_month_outlined, color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(child: AppTextField(controller: _weekday, hintText: 'Día de semana')),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: AppTextField(controller: _day, hintText: 'Día')),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(child: AppTextField(controller: _month, hintText: 'Mes')),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: AppTextField(controller: _year, hintText: 'Año')),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(controller: _timeLabel, hintText: 'Hora (texto, ej. 4:00 PM)'),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(controller: _description, hintText: 'Descripción', maxLines: 4),
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
