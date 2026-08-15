import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../design/design.dart';
import 'site_content_api.dart';
import 'site_content_widgets.dart';

/// Crear/editar un anuncio (tabla `anuncios`). `item == null` -> crear.
class AnuncioFormScreen extends StatefulWidget {
  const AnuncioFormScreen({super.key, this.item});

  final Map<String, dynamic>? item;

  @override
  State<AnuncioFormScreen> createState() => _AnuncioFormScreenState();
}

class _AnuncioFormScreenState extends State<AnuncioFormScreen> {
  final _api = SiteContentApi('anuncios');
  final _picker = ImagePicker();

  late final _titulo = TextEditingController(text: widget.item?['titulo']?.toString() ?? '');
  late final _descripcion = TextEditingController(text: widget.item?['descripcion']?.toString() ?? '');
  late final _fecha = TextEditingController(text: widget.item?['fecha_publicacion']?.toString() ?? '');
  late final _linkWeb = TextEditingController(text: widget.item?['link_web']?.toString() ?? '');
  late final _linkFacebook = TextEditingController(text: widget.item?['link_facebook']?.toString() ?? '');
  late final _linkWhatsapp = TextEditingController(text: widget.item?['link_whatsapp']?.toString() ?? '');

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
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null) return;
    setState(() {
      _fecha.text =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    });
  }

  Future<void> _submit() async {
    if (_titulo.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El título es obligatorio')),
      );
      return;
    }

    setState(() => _submitting = true);
    final fields = {
      'titulo': _titulo.text.trim(),
      'descripcion': _descripcion.text.trim(),
      'fecha_publicacion': _fecha.text.trim(),
      'link_web': _linkWeb.text.trim(),
      'link_facebook': _linkFacebook.text.trim(),
      'link_whatsapp': _linkWhatsapp.text.trim(),
    };

    try {
      if (_isEditing) {
        await _api.update(widget.item!['id'].toString(), fields, imageFile: _newImage, imageField: 'imagen');
      } else {
        await _api.create(fields, imageFile: _newImage, imageField: 'imagen');
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
    final existingImage = siteImageUrl(widget.item?['imagen_url']?.toString());

    return AppScaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar anuncio' : 'Nuevo anuncio'),
        leading: AppBackButton.leadingFor(context),
        automaticallyImplyLeading: false,
      ),
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.lg),
          AppTextField(controller: _titulo, hintText: 'Título *'),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(controller: _descripcion, hintText: 'Descripción', maxLines: 4),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            controller: _fecha,
            hintText: 'Fecha de publicación',
            readOnly: true,
            onTap: _pickDate,
            prefixIcon: const Icon(Icons.calendar_month_outlined, color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(controller: _linkWeb, hintText: 'Enlace a sitio web'),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(controller: _linkFacebook, hintText: 'Enlace de Facebook'),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(controller: _linkWhatsapp, hintText: 'Enlace de WhatsApp'),
          const SizedBox(height: AppSpacing.lg),
          SiteImagePickerField(
            newImage: _newImage,
            existingImageUrl: existingImage,
            onPick: _pickImage,
          ),
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
