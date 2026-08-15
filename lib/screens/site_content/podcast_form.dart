import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../design/design.dart';
import 'site_content_api.dart';
import 'site_content_widgets.dart';

/// Crear/editar un podcast (tabla `radio_podcasts` + `radio_podcast_episodes`).
/// `item == null` -> crear.
class PodcastFormScreen extends StatefulWidget {
  const PodcastFormScreen({super.key, this.item});

  final Map<String, dynamic>? item;

  @override
  State<PodcastFormScreen> createState() => _PodcastFormScreenState();
}

class _EpisodeRow {
  _EpisodeRow({String title = '', String category = '', String audio = '', String description = ''})
      : title = TextEditingController(text: title),
        category = TextEditingController(text: category),
        audio = TextEditingController(text: audio),
        description = TextEditingController(text: description);

  final TextEditingController title;
  final TextEditingController category;
  final TextEditingController audio;
  final TextEditingController description;
}

class _PodcastFormScreenState extends State<PodcastFormScreen> {
  final _api = SiteContentApi('podcasts');
  final _picker = ImagePicker();

  late final _title = TextEditingController(text: widget.item?['title']?.toString() ?? '');
  late final _filterIcon = TextEditingController(text: widget.item?['filter_icon']?.toString() ?? '');
  late final _sortOrder = TextEditingController(text: widget.item?['sort_order']?.toString() ?? '0');

  late final List<_EpisodeRow> _episodes = _initialEpisodes();

  File? _newCover;
  bool _submitting = false;

  bool get _isEditing => widget.item != null;

  List<_EpisodeRow> _initialEpisodes() {
    final raw = widget.item?['episodes'] as List?;
    if (raw == null || raw.isEmpty) return [_EpisodeRow()];
    return raw
        .map((e) => _EpisodeRow(
              title: e['title']?.toString() ?? '',
              category: e['category_label']?.toString() ?? '',
              audio: e['audio_url']?.toString() ?? '',
              description: e['description']?.toString() ?? '',
            ))
        .toList();
  }

  Future<void> _pickCover() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    setState(() => _newCover = File(picked.path));
  }

  Future<void> _submit() async {
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El título es obligatorio')),
      );
      return;
    }

    setState(() => _submitting = true);
    final episodesJson = jsonEncode(_episodes
        .map((e) => {
              'title': e.title.text.trim(),
              'category_label': e.category.text.trim(),
              'audio_url': e.audio.text.trim(),
              'description': e.description.text.trim(),
            })
        .where((e) => (e['title'] as String).isNotEmpty)
        .toList());

    final fields = {
      'title': _title.text.trim(),
      'filter_icon': _filterIcon.text.trim(),
      'sort_order': _sortOrder.text.trim().isEmpty ? '0' : _sortOrder.text.trim(),
      'episodes_json': episodesJson,
    };

    try {
      if (_isEditing) {
        await _api.update(widget.item!['id'].toString(), fields, imageFile: _newCover, imageField: 'cover');
      } else {
        await _api.create(fields, imageFile: _newCover, imageField: 'cover');
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
    final existingCover = siteImageUrl(widget.item?['cover']?.toString());

    return AppScaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar podcast' : 'Nuevo podcast'),
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
          AppTextField(controller: _filterIcon, hintText: 'Ícono de filtro'),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            controller: _sortOrder,
            hintText: 'Orden de aparición',
            textInputType: TextInputType.number,
          ),
          const SizedBox(height: AppSpacing.lg),
          SiteImagePickerField(newImage: _newCover, existingImageUrl: existingCover, onPick: _pickCover),
          const SizedBox(height: AppSpacing.xl),
          const Text(
            'Episodios',
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final episode in _episodes) ...[
            SiteRepeatRow(
              controllers: [episode.title, episode.category],
              hints: const ['Título del episodio', 'Categoría'],
              onRemove: () => setState(() => _episodes.remove(episode)),
            ),
            AppTextField(controller: episode.audio, hintText: 'assets/audio/podcasts/archivo.mp3'),
            const SizedBox(height: AppSpacing.xs),
            AppTextField(controller: episode.description, hintText: 'Descripción del episodio'),
            const SizedBox(height: AppSpacing.md),
          ],
          const Text(
            'El audio se sube por FTP/cPanel a assets/audio/podcasts/; aquí solo se '
            'escribe la ruta relativa del archivo.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton.icon(
            onPressed: () => setState(() => _episodes.add(_EpisodeRow())),
            icon: const Icon(Icons.add, color: AppColors.accent),
            label: const Text('Agregar episodio', style: TextStyle(color: AppColors.accent)),
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
