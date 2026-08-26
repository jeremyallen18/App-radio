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

  Future<void> _delete() async {
    final item = widget.item;
    if (item == null) return;
    final confirmed = await confirmSiteDelete(context, _name.text.trim());
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
      scrollable: true,
      showBackButton: false,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.md),
          SiteFormHeader(
            title: _isEditing ? 'Editar integrante' : 'Nuevo integrante',
            subtitle: 'Actualiza la información del integrante.',
          ),
          const SizedBox(height: AppSpacing.xl),
          SiteFormField(
            icon: Icons.person_outline,
            label: 'Nombre',
            required: true,
            controller: _name,
            hintText: 'Ingresa el nombre completo',
          ),
          const SizedBox(height: AppSpacing.md),
          SiteFormField(
            icon: Icons.work_outline,
            label: 'Rol',
            iconColor: SiteFieldColors.teal,
            controller: _role,
            hintText: 'Ej. Locutora de Rincón Lunar',
          ),
          const SizedBox(height: AppSpacing.md),
          SiteFormField(
            icon: Icons.sell_outlined,
            label: 'Categoría',
            iconColor: SiteFieldColors.green,
            controller: _category,
            hintText: 'Ej. locutores',
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
            icon: Icons.description_outlined,
            label: 'Descripción corta',
            iconColor: SiteFieldColors.orange,
            controller: _shortDesc,
            hintText: 'Breve descripción (máx. 150 caracteres)',
            maxLength: 150,
          ),
          const SizedBox(height: AppSpacing.md),
          SiteFormField(
            icon: Icons.menu_book_outlined,
            label: 'Biografía',
            iconColor: SiteFieldColors.purple,
            controller: _bio,
            hintText: 'Escribe la biografía del integrante…',
            helperText: 'Separa cada párrafo con una línea en blanco.',
            maxLines: 6,
            maxLength: 1000,
          ),
          const SizedBox(height: AppSpacing.md),
          SiteFormField(
            icon: Icons.trending_up,
            label: 'Trayectoria',
            iconColor: SiteFieldColors.teal,
            controller: _path,
            hintText: 'Añade cada hito o experiencia en una línea',
            maxLines: 4,
          ),
          const SizedBox(height: AppSpacing.md),
          SiteFormField(
            icon: Icons.star_outline,
            label: 'Intereses',
            iconColor: SiteFieldColors.orange,
            controller: _interests,
            hintText: 'Añade cada interés en una línea',
            maxLines: 4,
            maxLength: 500,
          ),
          const SizedBox(height: AppSpacing.md),
          SiteFormField(
            icon: Icons.swap_vert,
            label: 'Orden de aparición',
            controller: _sortOrder,
            hintText: 'Número de orden',
            textInputType: TextInputType.number,
          ),
          const SizedBox(height: AppSpacing.md),
          SiteImagePickerField(
            newImage: _newImage,
            existingImageUrl: existingImage,
            onPick: _pickImage,
            title: 'Imagen del integrante',
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
              label: 'Eliminar integrante',
              onPressed: _submitting ? null : _delete,
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}
