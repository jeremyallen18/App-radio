import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/features/dashboard/director/site_content/site_content_api.dart';
import 'package:doliv_social/features/dashboard/director/site_content/site_content_widgets.dart';

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
      scrollable: true,
      showBackButton: false,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.md),
          SiteFormHeader(
            title: _isEditing ? 'Editar servicio' : 'Nuevo servicio',
            subtitle: 'Actualiza la información de tu servicio',
          ),
          const SizedBox(height: AppSpacing.xl),
          SiteFormField(
            icon: Icons.title,
            label: 'Título',
            required: true,
            controller: _title,
            hintText: 'Ej. Transmisión en vivo',
          ),
          const SizedBox(height: AppSpacing.md),
          SiteFormField(
            icon: Icons.sell_outlined,
            label: 'Categoría',
            iconColor: SiteFieldColors.green,
            controller: _category,
            hintText: 'Selecciona una categoría',
          ),
          const SizedBox(height: AppSpacing.md),
          SiteFormField(
            icon: Icons.campaign_outlined,
            label: 'Ícono',
            iconColor: SiteFieldColors.purple,
            controller: _icon,
            hintText: 'Ej. megaphone, music, camera',
          ),
          const SizedBox(height: AppSpacing.md),
          SiteFormField(
            icon: Icons.notes_outlined,
            label: 'Descripción',
            iconColor: SiteFieldColors.orange,
            controller: _description,
            hintText: 'Describe tu servicio…',
            maxLines: 4,
          ),
          const SizedBox(height: AppSpacing.md),
          SiteFormField(
            icon: Icons.chat_outlined,
            label: 'Enlace de WhatsApp',
            iconColor: SiteFieldColors.whatsapp,
            controller: _whatsappUrl,
            hintText: 'https://wa.me/52XXXXXXXXXX',
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
            title: 'Imagen del servicio',
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
              label: 'Eliminar servicio',
              onPressed: _submitting ? null : _delete,
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}
