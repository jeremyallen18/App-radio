import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../design/design.dart';
import 'site_content_api.dart';
import 'site_content_widgets.dart';

/// Crear/editar un integrante del equipo (tabla `radio_team`).
/// `item == null` -> crear.
class EquipoFormScreen extends StatefulWidget {
  const EquipoFormScreen({super.key, this.item});

  final Map<String, dynamic>? item;

  @override
  State<EquipoFormScreen> createState() => _EquipoFormScreenState();
}

class _EquipoFormScreenState extends State<EquipoFormScreen> {
  final _api = SiteContentApi('equipo');
  final _picker = ImagePicker();

  late final _name = TextEditingController(text: widget.item?['name']?.toString() ?? '');
  late final _role = TextEditingController(text: widget.item?['role']?.toString() ?? '');
  late final _category = TextEditingController(text: widget.item?['category']?.toString() ?? '');
  late final _accent = TextEditingController(text: widget.item?['accent']?.toString() ?? '');
  late final _shortDesc = TextEditingController(text: widget.item?['short_desc']?.toString() ?? '');
  late final _bio = TextEditingController(text: widget.item?['bio']?.toString() ?? '');
  late final _path = TextEditingController(text: widget.item?['path']?.toString() ?? '');
  late final _interests = TextEditingController(text: widget.item?['interests']?.toString() ?? '');
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
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El nombre es obligatorio')),
      );
      return;
    }

    setState(() => _submitting = true);
    final fields = {
      'name': _name.text.trim(),
      'role': _role.text.trim(),
      'category': _category.text.trim(),
      'accent': _accent.text.trim(),
      'short_desc': _shortDesc.text.trim(),
      'bio': _bio.text,
      'path': _path.text,
      'interests': _interests.text,
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
        title: Text(_isEditing ? 'Editar integrante' : 'Nuevo integrante'),
        leading: AppBackButton.leadingFor(context),
        automaticallyImplyLeading: false,
      ),
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.lg),
          AppTextField(controller: _name, hintText: 'Nombre *'),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(controller: _role, hintText: 'Rol (ej. Locutora de Rincón Lunar)'),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(controller: _category, hintText: 'Categoría (ej. locutores)'),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(controller: _accent, hintText: 'Color de identidad (hex, ej. #3d5afe)'),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(controller: _shortDesc, hintText: 'Descripción corta'),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            controller: _bio,
            hintText: 'Biografía (separa cada párrafo con una línea en blanco)',
            maxLines: 6,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(controller: _path, hintText: 'Trayectoria (un elemento por línea)', maxLines: 4),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(controller: _interests, hintText: 'Intereses (un elemento por línea)', maxLines: 4),
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
