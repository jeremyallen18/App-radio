import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../design/design.dart';
import 'site_content_api.dart';
import 'site_content_widgets.dart';

/// Crear/editar un servicio (tabla `radio_services`). `item == null` -> crear.
class ServicioFormScreen extends StatefulWidget {
  const ServicioFormScreen({super.key, this.item});

  final Map<String, dynamic>? item;

  @override
  State<ServicioFormScreen> createState() => _ServicioFormScreenState();
}

class _ServicioFormScreenState extends State<ServicioFormScreen> {
  final _api = SiteContentApi('servicios');
  final _picker = ImagePicker();

  late final _title = TextEditingController(text: widget.item?['title']?.toString() ?? '');
  late final _category = TextEditingController(text: widget.item?['category']?.toString() ?? '');
  late final _icon = TextEditingController(text: widget.item?['icon']?.toString() ?? '');
  late final _description = TextEditingController(text: widget.item?['description']?.toString() ?? '');
  late final _whatsappUrl = TextEditingController(text: widget.item?['whatsapp_url']?.toString() ?? '');
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
      'category': _category.text.trim(),
      'icon': _icon.text.trim(),
      'description': _description.text.trim(),
      'whatsapp_url': _whatsappUrl.text.trim(),
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
        title: Text(_isEditing ? 'Editar servicio' : 'Nuevo servicio'),
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
          AppTextField(controller: _category, hintText: 'Categoría'),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(controller: _icon, hintText: 'Ícono (nombre lucide, ej. megaphone)'),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(controller: _description, hintText: 'Descripción', maxLines: 4),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(controller: _whatsappUrl, hintText: 'Enlace de WhatsApp'),
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
