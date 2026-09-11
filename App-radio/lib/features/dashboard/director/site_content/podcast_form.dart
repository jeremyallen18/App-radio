import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/features/dashboard/director/site_content/site_content_api.dart';
import 'package:doliv_social/features/dashboard/director/site_content/site_content_widgets.dart';

/// Crear/editar un podcast (tabla `radio_podcasts` + `radio_podcast_episodes`).
/// `item == null` -> crear.
class PodcastFormScreen extends StatefulWidget {
  const PodcastFormScreen({super.key, this.item});

  final Map<String, dynamic>? item;

  @override
  State<PodcastFormScreen> createState() => _PodcastFormScreenState();
}

class _EpisodeRow {
  _EpisodeRow(
      {String title = '',
      String category = '',
      String audio = '',
      String description = ''})
      : title = TextEditingController(text: title),
        category = TextEditingController(text: category),
        audio = TextEditingController(text: audio),
        description = TextEditingController(text: description);

  final TextEditingController title;
  final TextEditingController category;
  final TextEditingController audio;
  final TextEditingController description;
  File? audioFile;
}

class _PodcastFormScreenState extends State<PodcastFormScreen> {
  final _api = SiteContentApi('podcasts');
  final _picker = ImagePicker();

  late final _title =
      TextEditingController(text: widget.item?['title']?.toString() ?? '');
  late final _filterIcon = TextEditingController(
      text: widget.item?['filter_icon']?.toString() ?? '');
  late final _sortOrder = TextEditingController(
      text: widget.item?['sort_order']?.toString() ?? '0');

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
    final picked =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    setState(() => _newCover = File(picked.path));
  }

  Future<void> _pickEpisodeAudio(_EpisodeRow episode) async {
    final file = await FilePicker.pickFile(type: FileType.audio);
    final path = file?.path;
    if (path == null) return;
    setState(() {
      episode.audioFile = File(path);
      episode.audio.text = file!.name;
    });
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
    final filledEpisodes = _episodes
        .where((episode) => episode.title.text.trim().isNotEmpty)
        .toList();
    final episodesJson = jsonEncode(filledEpisodes
        .map((e) => {
              'title': e.title.text.trim(),
              'category_label': e.category.text.trim(),
              'audio_url': e.audio.text.trim(),
              'description': e.description.text.trim(),
            })
        .where((e) => (e['title'] as String).isNotEmpty)
        .toList());
    final episodeAudioFiles = <String, File>{
      for (var index = 0; index < filledEpisodes.length; index++)
        if (filledEpisodes[index].audioFile != null)
          'episode_audio_$index': filledEpisodes[index].audioFile!,
    };

    final fields = {
      'title': _title.text.trim(),
      'filter_icon': _filterIcon.text.trim(),
      'sort_order':
          _sortOrder.text.trim().isEmpty ? '0' : _sortOrder.text.trim(),
      'episodes_json': episodesJson,
    };

    try {
      if (_isEditing) {
        await _api.update(widget.item!['id'].toString(), fields,
            imageFile: _newCover,
            imageField: 'cover',
            additionalFiles: episodeAudioFiles);
      } else {
        await _api.create(fields,
            imageFile: _newCover,
            imageField: 'cover',
            additionalFiles: episodeAudioFiles);
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
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.md),
          SiteFormHeader(
            title: _isEditing ? 'Editar podcast' : 'Nuevo podcast',
            subtitle: 'Actualiza la información de tu podcast',
          ),
          const SizedBox(height: AppSpacing.xl),
          SiteFormField(
            icon: Icons.title,
            label: 'Título',
            required: true,
            controller: _title,
            hintText: 'Ej. Voces de la ciudad',
          ),
          const SizedBox(height: AppSpacing.md),
          SiteFormField(
            icon: Icons.filter_alt_outlined,
            label: 'Ícono de filtro',
            iconColor: SiteFieldColors.purple,
            controller: _filterIcon,
            hintText: 'Nombre del ícono',
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
            newImage: _newCover,
            existingImageUrl: existingCover,
            onPick: _pickCover,
            title: 'Portada del podcast',
          ),
          const SizedBox(height: AppSpacing.xl),
          const SiteFormSectionTitle('Episodios'),
          const SizedBox(height: AppSpacing.sm),
          for (final episode in _episodes) ...[
            SiteRepeatRow(
              controllers: [episode.title, episode.category],
              hints: const ['Título del episodio', 'Categoría'],
              onRemove: () => setState(() => _episodes.remove(episode)),
            ),
            _EpisodeAudioField(
              controller: episode.audio,
              selectedFile: episode.audioFile,
              onPick: () => _pickEpisodeAudio(episode),
            ),
            const SizedBox(height: AppSpacing.xs),
            AppTextField(
                controller: episode.description,
                hintText: 'Descripción del episodio'),
            const SizedBox(height: AppSpacing.md),
          ],
          Text(
            'Carga un archivo de audio o conserva/escribe una ruta existente.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton.icon(
            onPressed: () => setState(() => _episodes.add(_EpisodeRow())),
            icon: Icon(Icons.add, color: AppColors.accent),
            label: Text('Agregar episodio',
                style: TextStyle(color: AppColors.accent)),
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
              label: 'Eliminar podcast',
              onPressed: _submitting ? null : _delete,
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

class _EpisodeAudioField extends StatelessWidget {
  const _EpisodeAudioField({
    required this.controller,
    required this.selectedFile,
    required this.onPick,
  });

  final TextEditingController controller;
  final File? selectedFile;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPick,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        child: Ink(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.chip),
            border: Border.all(color: AppColors.surfaceBorder),
            color: AppColors.surface,
          ),
          child: Row(
            children: [
              Icon(Icons.audio_file_outlined, color: SiteFieldColors.purple),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  selectedFile?.path.split(Platform.pathSeparator).last ??
                      (controller.text.trim().isEmpty
                          ? 'Toca para cargar el audio'
                          : controller.text.trim()),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: controller.text.trim().isEmpty
                        ? AppColors.textMuted
                        : AppColors.textPrimary,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(Icons.upload_file_outlined, color: AppColors.accent),
            ],
          ),
        ),
      ),
    );
  }
}
