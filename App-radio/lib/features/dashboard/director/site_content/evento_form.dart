import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/features/dashboard/director/site_content/site_content_api.dart';
import 'package:doliv_social/features/dashboard/director/site_content/site_content_widgets.dart';

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

  late final _title =
      TextEditingController(text: widget.item?['title']?.toString() ?? '');
  late final _artist =
      TextEditingController(text: widget.item?['artist']?.toString() ?? '');
  late final _location =
      TextEditingController(text: widget.item?['location']?.toString() ?? '');
  late final _eventDate =
      TextEditingController(text: widget.item?['event_date']?.toString() ?? '');
  late final _weekday =
      TextEditingController(text: widget.item?['weekday']?.toString() ?? '');
  late final _day =
      TextEditingController(text: widget.item?['day']?.toString() ?? '');
  late final _month =
      TextEditingController(text: widget.item?['month']?.toString() ?? '');
  late final _year =
      TextEditingController(text: widget.item?['year']?.toString() ?? '');
  late final _timeLabel =
      TextEditingController(text: widget.item?['time_label']?.toString() ?? '');
  late final _description = TextEditingController(
      text: widget.item?['description']?.toString() ?? '');

  File? _newImage;
  bool _submitting = false;

  bool get _isEditing => widget.item != null;

  @override
  void initState() {
    super.initState();
    _title.addListener(_refreshCta);
    _eventDate.addListener(_syncDateParts);
    _syncDateParts();
  }

  void _refreshCta() {
    if (mounted) setState(() {});
  }

  void _syncDateParts() {
    final date = DateTime.tryParse(_eventDate.text.trim());
    if (date == null) return;
    const weekdays = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo',
    ];
    const months = [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];
    _weekday.text = weekdays[date.weekday - 1];
    _day.text = date.day.toString();
    _month.text = months[date.month - 1];
    _year.text = date.year.toString();
  }

  Future<void> _pickImage() async {
    final picked =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
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
    final sortOrder = _isEditing
        ? int.tryParse(widget.item?['sort_order']?.toString() ?? '') ?? 0
        : await _api.nextSortOrder();
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
      'sort_order': sortOrder.toString(),
    };

    try {
      if (_isEditing) {
        await _api.update(widget.item!['id'].toString(), fields,
            imageFile: _newImage);
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
  void dispose() {
    _title.removeListener(_refreshCta);
    _eventDate.removeListener(_syncDateParts);
    _title.dispose();
    _artist.dispose();
    _location.dispose();
    _eventDate.dispose();
    _weekday.dispose();
    _day.dispose();
    _month.dispose();
    _year.dispose();
    _timeLabel.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final existingImage = siteImageUrl(widget.item?['image']?.toString());

    return AppScaffold(
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.lg),
          child: FilledButton.icon(
            onPressed:
                _title.text.trim().isEmpty || _submitting ? null : _submit,
            icon: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: Text(_submitting ? 'Guardando...' : 'Guardar evento'),
          ),
        ),
      ),
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.md),
          SiteFormHeader(
            title: _isEditing ? 'Editar evento' : 'Nuevo evento',
            subtitle: 'Actualiza la información de tu evento',
          ),
          const SizedBox(height: AppSpacing.xl),
          SiteFormField(
            icon: Icons.title,
            label: 'Título',
            required: true,
            controller: _title,
            hintText: 'Ej. Festival de verano',
          ),
          const SizedBox(height: AppSpacing.md),
          SiteFormField(
            icon: Icons.mic_outlined,
            label: 'Artista / presentador',
            iconColor: SiteFieldColors.purple,
            controller: _artist,
            hintText: 'Ej. DJ Doliv',
          ),
          const SizedBox(height: AppSpacing.md),
          SiteFormField(
            icon: Icons.place_outlined,
            label: 'Lugar',
            iconColor: SiteFieldColors.teal,
            controller: _location,
            hintText: 'Ej. Plaza principal',
          ),
          const SizedBox(height: AppSpacing.md),
          SiteDatePickerField(
            label: 'Fecha del evento',
            controller: _eventDate,
            hintText: 'Vacío = "Próximamente"',
          ),
          const SizedBox(height: AppSpacing.md),
          SiteTimePickerField(
            label: 'Hora',
            controller: _timeLabel,
            hintText: 'Elige la hora de inicio',
          ),
          const SizedBox(height: AppSpacing.md),
          SiteFormField(
            icon: Icons.notes_outlined,
            label: 'Descripción',
            iconColor: SiteFieldColors.orange,
            controller: _description,
            hintText: 'Describe el evento…',
            maxLines: 4,
          ),
          const SizedBox(height: AppSpacing.md),
          SiteImagePickerField(
            newImage: _newImage,
            existingImageUrl: existingImage,
            onPick: _pickImage,
            title: 'Imagen del evento',
          ),
          if (_isEditing) ...[
            const SizedBox(height: AppSpacing.md),
            SiteDeleteButton(
              label: 'Eliminar evento',
              onPressed: _submitting ? null : _delete,
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}
