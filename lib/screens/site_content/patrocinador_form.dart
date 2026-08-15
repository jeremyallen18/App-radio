import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../design/design.dart';
import 'site_content_api.dart';
import 'site_content_widgets.dart';

/// Crear/editar un patrocinador de la Sección Azul (tabla `sponsors` +
/// `sponsor_socials`). `item == null` -> crear.
class PatrocinadorFormScreen extends StatefulWidget {
  const PatrocinadorFormScreen({super.key, this.item});

  final Map<String, dynamic>? item;

  @override
  State<PatrocinadorFormScreen> createState() => _PatrocinadorFormScreenState();
}

class _SocialRow {
  _SocialRow({String label = '', String icon = '', String url = ''})
      : label = TextEditingController(text: label),
        icon = TextEditingController(text: icon),
        url = TextEditingController(text: url);

  final TextEditingController label;
  final TextEditingController icon;
  final TextEditingController url;
}

class _PatrocinadorFormScreenState extends State<PatrocinadorFormScreen> {
  final _api = SiteContentApi('patrocinadores');
  final _picker = ImagePicker();

  late final _name = TextEditingController(text: widget.item?['name']?.toString() ?? '');
  late final _category = TextEditingController(text: widget.item?['category']?.toString() ?? '');
  late final _categoryLabel = TextEditingController(text: widget.item?['category_label']?.toString() ?? '');
  late final _icon = TextEditingController(text: widget.item?['icon']?.toString() ?? '');
  late final _subtitle = TextEditingController(text: widget.item?['subtitle']?.toString() ?? '');
  late final _summary = TextEditingController(text: widget.item?['summary']?.toString() ?? '');
  late final _description = TextEditingController(text: widget.item?['description']?.toString() ?? '');
  late final _map = TextEditingController(text: widget.item?['map']?.toString() ?? '');
  late final _sortOrder = TextEditingController(text: widget.item?['sort_order']?.toString() ?? '0');

  late final List<_SocialRow> _socials = _initialSocials();

  File? _newImage;
  bool _submitting = false;

  bool get _isEditing => widget.item != null;

  List<_SocialRow> _initialSocials() {
    final raw = widget.item?['socials'] as List?;
    if (raw == null || raw.isEmpty) return [_SocialRow()];
    return raw
        .map((s) => _SocialRow(
              label: s['label']?.toString() ?? '',
              icon: s['icon']?.toString() ?? '',
              url: s['url']?.toString() ?? '',
            ))
        .toList();
  }

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
    final socialsJson = jsonEncode(_socials
        .map((s) => {'label': s.label.text.trim(), 'icon': s.icon.text.trim(), 'url': s.url.text.trim()})
        .where((s) => (s['label'] as String).isNotEmpty || (s['url'] as String).isNotEmpty)
        .toList());

    final fields = {
      'name': _name.text.trim(),
      'category': _category.text.trim(),
      'category_label': _categoryLabel.text.trim(),
      'icon': _icon.text.trim(),
      'subtitle': _subtitle.text.trim(),
      'summary': _summary.text.trim(),
      'description': _description.text,
      'map': _map.text.trim(),
      'sort_order': _sortOrder.text.trim().isEmpty ? '0' : _sortOrder.text.trim(),
      'socials_json': socialsJson,
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
        title: Text(_isEditing ? 'Editar patrocinador' : 'Nuevo patrocinador'),
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
          AppTextField(controller: _category, hintText: 'Categoría (clave, ej. escuelas)'),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(controller: _categoryLabel, hintText: 'Etiqueta de categoría (ej. Escuelas)'),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(controller: _icon, hintText: 'Ícono (nombre lucide)'),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(controller: _subtitle, hintText: 'Subtítulo'),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(controller: _summary, hintText: 'Resumen', maxLines: 3),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            controller: _description,
            hintText: 'Descripción larga (separa cada párrafo con una línea en blanco)',
            maxLines: 6,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(controller: _map, hintText: 'Mapa (URL embed de Google Maps)'),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            controller: _sortOrder,
            hintText: 'Orden de aparición',
            textInputType: TextInputType.number,
          ),
          const SizedBox(height: AppSpacing.xl),
          const Text(
            'Redes sociales',
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final social in _socials)
            SiteRepeatRow(
              controllers: [social.label, social.icon, social.url],
              hints: const ['Etiqueta (Facebook)', 'Ícono (facebook)', 'https://...'],
              onRemove: () => setState(() => _socials.remove(social)),
            ),
          TextButton.icon(
            onPressed: () => setState(() => _socials.add(_SocialRow())),
            icon: const Icon(Icons.add, color: AppColors.accent),
            label: const Text('Agregar red social', style: TextStyle(color: AppColors.accent)),
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
