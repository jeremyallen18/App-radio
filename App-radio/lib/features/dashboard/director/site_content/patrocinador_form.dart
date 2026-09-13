import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/features/dashboard/director/site_content/site_content_api.dart';
import 'package:doliv_social/features/dashboard/director/site_content/site_content_widgets.dart';

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

  late final _name =
      TextEditingController(text: widget.item?['name']?.toString() ?? '');
  late String _category =
      (widget.item?['category']?.toString().trim().isNotEmpty ?? false)
          ? widget.item!['category'].toString().trim()
          : 'comercios';
  late String _categoryLabel =
      (widget.item?['category_label']?.toString().trim().isNotEmpty ?? false)
          ? widget.item!['category_label'].toString().trim()
          : 'Comercios';
  late String _icon =
      (widget.item?['icon']?.toString().trim().isNotEmpty ?? false)
          ? widget.item!['icon'].toString().trim()
          : 'store';
  late final _subtitle =
      TextEditingController(text: widget.item?['subtitle']?.toString() ?? '');
  late final _summary =
      TextEditingController(text: widget.item?['summary']?.toString() ?? '');
  late final _description = TextEditingController(
      text: widget.item?['description']?.toString() ?? '');
  late final _map =
      TextEditingController(text: widget.item?['map']?.toString() ?? '');
  late final List<_SocialRow> _socials = _initialSocials();

  static const _categoryOptions = [
    SiteChoiceOption('comercios', 'Comercios'),
    SiteChoiceOption('escuelas', 'Escuelas'),
    SiteChoiceOption('restaurantes', 'Restaurantes'),
    SiteChoiceOption('servicios', 'Servicios'),
    SiteChoiceOption('salud', 'Salud'),
  ];

  File? _newImage;
  bool _submitting = false;

  bool get _isEditing => widget.item != null;

  @override
  void initState() {
    super.initState();
    _name.addListener(_refreshCta);
  }

  void _refreshCta() {
    if (mounted) setState(() {});
  }

  void _selectCategory(String value) {
    final option = _categoryOptions.firstWhere(
      (option) => option.value == value,
      orElse: () => _categoryOptions.first,
    );
    setState(() {
      _category = option.value;
      _categoryLabel = option.label;
    });
  }

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
    final picked =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
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
    final socialsJson = jsonEncode(_socials
        .map((s) => {
              'label': s.label.text.trim(),
              'icon': s.icon.text.trim(),
              'url': s.url.text.trim()
            })
        .where((s) =>
            (s['label'] as String).isNotEmpty ||
            (s['url'] as String).isNotEmpty)
        .toList());

    final sortOrder = _isEditing
        ? int.tryParse(widget.item?['sort_order']?.toString() ?? '') ?? 0
        : await _api.nextSortOrder();
    final fields = {
      'name': _name.text.trim(),
      'category': _category,
      'category_label': _categoryLabel,
      'icon': _icon,
      'subtitle': _subtitle.text.trim(),
      'summary': _summary.text.trim(),
      'description': _description.text,
      'map': _map.text.trim(),
      'sort_order': sortOrder.toString(),
      'socials_json': socialsJson,
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
    _name.removeListener(_refreshCta);
    _name.dispose();
    _subtitle.dispose();
    _summary.dispose();
    _description.dispose();
    _map.dispose();
    for (final social in _socials) {
      social.label.dispose();
      social.icon.dispose();
      social.url.dispose();
    }
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
                _name.text.trim().isEmpty || _submitting ? null : _submit,
            icon: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: Text(_submitting ? 'Guardando...' : 'Guardar patrocinador'),
          ),
        ),
      ),
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.md),
          SiteFormHeader(
            title: _isEditing ? 'Editar patrocinador' : 'Nuevo patrocinador',
            subtitle: 'Actualiza la información del patrocinador',
          ),
          const SizedBox(height: AppSpacing.xl),
          SiteFormField(
            icon: Icons.storefront_outlined,
            label: 'Nombre',
            required: true,
            controller: _name,
            hintText: 'Ej. Panadería El Trigo',
          ),
          const SizedBox(height: AppSpacing.md),
          SiteChoiceChipsField(
            icon: Icons.sell_outlined,
            label: 'Categoría',
            iconColor: SiteFieldColors.green,
            options: _categoryOptions,
            value: _category,
            onChanged: _selectCategory,
          ),
          const SizedBox(height: AppSpacing.md),
          SiteIconPickerField(
            icon: Icons.emoji_symbols_outlined,
            label: 'Ícono',
            iconColor: SiteFieldColors.purple,
            value: _icon,
            onChanged: (option) => setState(() => _icon = option.value),
          ),
          const SizedBox(height: AppSpacing.md),
          SiteFormField(
            icon: Icons.short_text,
            label: 'Subtítulo',
            iconColor: SiteFieldColors.teal,
            controller: _subtitle,
            hintText: 'Subtítulo del patrocinador',
          ),
          const SizedBox(height: AppSpacing.md),
          SiteFormField(
            icon: Icons.notes_outlined,
            label: 'Resumen',
            iconColor: SiteFieldColors.orange,
            controller: _summary,
            hintText: 'Resumen breve',
            maxLines: 3,
          ),
          const SizedBox(height: AppSpacing.md),
          SiteFormField(
            icon: Icons.menu_book_outlined,
            label: 'Descripción larga',
            iconColor: SiteFieldColors.orange,
            controller: _description,
            hintText: 'Describe al patrocinador…',
            helperText: 'Separa cada párrafo con una línea en blanco.',
            maxLines: 6,
          ),
          const SizedBox(height: AppSpacing.md),
          SiteFormField(
            icon: Icons.map_outlined,
            label: 'Mapa',
            iconColor: SiteFieldColors.teal,
            controller: _map,
            hintText: 'URL embed de Google Maps',
          ),
          const SizedBox(height: AppSpacing.md),
          const SizedBox(height: AppSpacing.xl),
          const SiteFormSectionTitle('Redes sociales'),
          const SizedBox(height: AppSpacing.sm),
          for (final social in _socials)
            SiteSocialLinkRow(
              key: ObjectKey(social),
              labelController: social.label,
              iconController: social.icon,
              urlController: social.url,
              onRemove: () => setState(() => _socials.remove(social)),
            ),
          TextButton.icon(
            onPressed: () => setState(() => _socials.add(_SocialRow())),
            icon: Icon(Icons.add, color: AppColors.accent),
            label: Text('Agregar red social',
                style: TextStyle(color: AppColors.accent)),
          ),
          const SizedBox(height: AppSpacing.md),
          SiteImagePickerField(
            newImage: _newImage,
            existingImageUrl: existingImage,
            onPick: _pickImage,
            title: 'Imagen del patrocinador',
          ),
          if (_isEditing) ...[
            const SizedBox(height: AppSpacing.md),
            SiteDeleteButton(
              label: 'Eliminar patrocinador',
              onPressed: _submitting ? null : _delete,
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}
