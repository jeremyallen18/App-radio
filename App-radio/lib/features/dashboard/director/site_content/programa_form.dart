import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:image_picker/image_picker.dart';

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/features/dashboard/director/site_content/program_model.dart';
import 'package:doliv_social/features/dashboard/director/site_content/site_content_api.dart';
import 'package:doliv_social/features/dashboard/director/site_content/site_content_widgets.dart';

class ProgramaFormScreen extends StatefulWidget {
  const ProgramaFormScreen({super.key, this.item});

  final Map<String, dynamic>? item;

  @override
  State<ProgramaFormScreen> createState() => _ProgramaFormScreenState();
}

String _joinNamesWithY(List<String> names) {
  if (names.isEmpty) return '';
  if (names.length == 1) return names.first;
  final last = names.last;
  return '${names.sublist(0, names.length - 1).join(', ')} y $last';
}

class ProgramFormController extends ChangeNotifier {
  ProgramFormController(ProgramModel initial) : _model = initial;

  ProgramModel _model;
  ProgramModel get model => _model;
  bool get isValid => _model.isValid;

  void updateTitle(String value) => _set(_model.copyWith(title: value));
  void updateModalTitle(String value) =>
      _set(_model.copyWith(modalTitle: value));
  void updateHost(String value) => _set(_model.copyWith(host: value));
  void updateBadgeLabel(String value) =>
      _set(_model.copyWith(badgeLabel: value));
  void updateCardDesc(String value) => _set(_model.copyWith(cardDesc: value));
  void updateIndexDesc(String value) => _set(_model.copyWith(indexDesc: value));
  void updateSummary(String value) => _set(_model.copyWith(summary: value));

  void updateColor(Color color) {
    final accessible = _ensureVisibleOnCurrentSurface(color);
    _set(_model.copyWith(accent: _hexFromColor(accessible)));
  }

  void updateIcon(ProgramIconOption option) {
    _set(_model.copyWith(icon: option.value, badgeIcon: option.value));
  }

  void updateTags(List<String> tags) {
    _set(_model.copyWith(
      categories: tags.isEmpty ? const [ProgramModel.defaultTag] : tags,
    ));
  }

  void updateHosts(Set<int> ids, List<SiteLinkOption> options) {
    final labelById = {for (final option in options) option.id: option.label};
    _set(_model.copyWith(
      hostTeamIds: ids,
      host: ids.isEmpty
          ? _model.host
          : _joinNamesWithY(
              ids.map((id) => labelById[id]).whereType<String>().toList(),
            ),
    ));
  }

  void updateSlotStart(int? hour) {
    _set(_withSyncedSchedule(_model.copyWith(slotStart: hour)));
  }

  void updateSlotEnd(int? hour) {
    _set(_withSyncedSchedule(_model.copyWith(slotEnd: hour)));
  }

  void updateWeekdays(Set<int> days) {
    _set(_withSyncedSchedule(_model.copyWith(weekdays: days)));
  }

  void updateOrderIndex(int orderIndex) {
    _set(_model.copyWith(orderIndex: orderIndex));
  }

  void _set(ProgramModel next) {
    if (next == _model) return;
    _model = next;
    notifyListeners();
  }

  ProgramModel _withSyncedSchedule(ProgramModel current) {
    final start = current.slotStart;
    final end = current.slotEnd;
    if (start == null || end == null) {
      return current.copyWith(schedule: '', badgeTime: '');
    }
    const labels = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    final days = current.weekdays.toList()..sort();
    final daysLabel = days.isEmpty
        ? 'Todos los días'
        : days.map((day) => labels[day - 1]).join(', ');
    final timeRange =
        '${start.toString().padLeft(2, '0')}:00 - ${end.toString().padLeft(2, '0')}:00';
    return current.copyWith(
      schedule: '$daysLabel | $timeRange',
      badgeTime: timeRange,
    );
  }

  static String _hexFromColor(Color color) {
    return '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
  }

  static Color _ensureVisibleOnCurrentSurface(Color color) {
    Color candidate = color.withAlpha(255);
    final background = AppColors.bgBase;
    final preferLighter =
        ThemeData.estimateBrightnessForColor(background) == Brightness.dark;

    for (var i = 0; i < 8; i++) {
      if (_contrastRatio(candidate, background) >= 3) return candidate;
      final hsl = HSLColor.fromColor(candidate);
      final lightness = (hsl.lightness + (preferLighter ? 0.08 : -0.08))
          .clamp(0.18, 0.82)
          .toDouble();
      candidate = hsl.withLightness(lightness).toColor();
    }
    return candidate;
  }

  static double _contrastRatio(Color a, Color b) {
    final bright = a.computeLuminance() > b.computeLuminance() ? a : b;
    final dark = identical(bright, a) ? b : a;
    return (bright.computeLuminance() + 0.05) /
        (dark.computeLuminance() + 0.05);
  }
}

class _ProgramaFormScreenState extends State<ProgramaFormScreen> {
  final _api = SiteContentApi('programas');
  final _equipoApi = SiteContentApi('equipo');
  final _picker = ImagePicker();

  late final ProgramFormController _form;
  late final TextEditingController _title;
  late final TextEditingController _modalTitle;
  late final TextEditingController _host;
  late final TextEditingController _badgeLabel;
  late final TextEditingController _cardDesc;
  late final TextEditingController _indexDesc;
  late final TextEditingController _summary;
  late final Future<List<SiteLinkOption>> _hostOptionsFuture;

  File? _newImage;
  bool _submitting = false;

  bool get _isEditing => widget.item != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.item == null
        ? ProgramModel.empty()
        : ProgramModel.fromSiteItem(widget.item!);
    _form = ProgramFormController(initial);
    _title = TextEditingController(text: initial.title)
      ..addListener(() => _form.updateTitle(_title.text));
    _modalTitle = TextEditingController(text: initial.modalTitle)
      ..addListener(() => _form.updateModalTitle(_modalTitle.text));
    _host = TextEditingController(text: initial.host)
      ..addListener(() => _form.updateHost(_host.text));
    _badgeLabel = TextEditingController(text: initial.badgeLabel)
      ..addListener(() => _form.updateBadgeLabel(_badgeLabel.text));
    _cardDesc = TextEditingController(text: initial.cardDesc)
      ..addListener(() => _form.updateCardDesc(_cardDesc.text));
    _indexDesc = TextEditingController(text: initial.indexDesc)
      ..addListener(() => _form.updateIndexDesc(_indexDesc.text));
    _summary = TextEditingController(text: initial.summary)
      ..addListener(() => _form.updateSummary(_summary.text));
    _hostOptionsFuture = _loadHostOptions();
    _form.addListener(_syncControllersFromForm);
  }

  void _syncControllersFromForm() {
    final model = _form.model;
    if (_host.text != model.host) _host.text = model.host;
  }

  Future<List<SiteLinkOption>> _loadHostOptions() async {
    final items = await _equipoApi.list();
    return items.map((item) {
      final role = (item['role'] ?? '').toString();
      return SiteLinkOption(
        id: int.parse(item['id'].toString()),
        label: (item['name'] ?? '').toString(),
        subtitle: role.isEmpty ? null : role,
      );
    }).toList();
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
    final confirmed = await confirmSiteDelete(context, _form.model.title);
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
    if (!_form.isValid || _submitting) return;

    setState(() => _submitting = true);
    try {
      if (!_isEditing) {
        final existing = await _api.list();
        _form.updateOrderIndex(ProgramModel.nextOrderIndex(existing));
      }
      final fields = _form.model.toSiteFields();
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
    _form.removeListener(_syncControllersFromForm);
    _form.dispose();
    _title.dispose();
    _modalTitle.dispose();
    _host.dispose();
    _badgeLabel.dispose();
    _cardDesc.dispose();
    _indexDesc.dispose();
    _summary.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final existingImage = siteImageUrl(widget.item?['image']?.toString());

    return AnimatedBuilder(
      animation: _form,
      builder: (context, _) {
        final model = _form.model;
        return AppScaffold(
          bottomNavigationBar: SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.md,
                AppSpacing.xl,
                AppSpacing.lg,
              ),
              decoration: BoxDecoration(
                color: AppColors.bgBase,
                border: Border(top: BorderSide(color: AppColors.surfaceBorder)),
              ),
              child: FilledButton.icon(
                onPressed: model.isValid && !_submitting ? _submit : null,
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: Text(_submitting ? 'Guardando...' : 'Guardar programa'),
              ),
            ),
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.md),
              SiteFormHeader(
                title: _isEditing ? 'Editar programa' : 'Nuevo programa',
                subtitle: _isEditing
                    ? 'Ajusta identidad, horario y contenido'
                    : 'Con un título basta; lo demás ya tiene punto de partida',
              ),
              const SizedBox(height: AppSpacing.lg),
              ProgramLivePreview(model: model),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
                  children: [
                    SiteFormField(
                      icon: Icons.title,
                      label: 'Título',
                      required: true,
                      controller: _title,
                      hintText: 'Ej. Rincón Lunar',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ProgramColorPaletteField(
                      selected: parseHexColor(model.accent) ??
                          const Color(0xFF2563EB),
                      onChanged: _form.updateColor,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ProgramIconPickerField(
                      selectedValue: model.icon,
                      onChanged: _form.updateIcon,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ProgramTagManagerField(
                      tags: model.categories,
                      onChanged: _form.updateTags,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    FutureBuilder<List<SiteLinkOption>>(
                      future: _hostOptionsFuture,
                      builder: (context, snapshot) {
                        final options = snapshot.data ?? const [];
                        return SiteMultiLinkPickerField(
                          icon: Icons.badge_outlined,
                          label: 'Locutores vinculados',
                          iconColor: SiteFieldColors.teal,
                          options: options,
                          selectedIds: model.hostTeamIds,
                          onChanged: (ids) => _form.updateHosts(ids, options),
                          helperText: snapshot.connectionState ==
                                  ConnectionState.waiting
                              ? 'Cargando integrantes...'
                              : 'Opcional: elige a uno o varios integrantes de Equipo.',
                          emptyMessage:
                              'Todavía no hay integrantes en Equipo. Créalos primero ahí.',
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SiteFormField(
                      icon: Icons.person_outline,
                      label: 'Conductor(a)',
                      iconColor: SiteFieldColors.teal,
                      controller: _host,
                      hintText: 'Nombre visible del conductor o conductora',
                      readOnly: model.hostTeamIds.isNotEmpty,
                      helperText: model.hostTeamIds.isNotEmpty
                          ? 'Se completa con los integrantes vinculados.'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _ScheduleSection(form: _form),
                    const SizedBox(height: AppSpacing.md),
                    SiteFormField(
                      icon: Icons.label_outline,
                      label: 'Texto de insignia',
                      iconColor: SiteFieldColors.purple,
                      controller: _badgeLabel,
                      hintText: 'Ej. Al aire',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SiteFormField(
                      icon: Icons.web_asset_outlined,
                      label: 'Título del detalle',
                      controller: _modalTitle,
                      hintText: 'Si lo dejas vacío, se usa el título',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SiteFormField(
                      icon: Icons.notes_outlined,
                      label: 'Descripción de tarjeta',
                      iconColor: SiteFieldColors.orange,
                      controller: _cardDesc,
                      hintText: 'Descripción corta para la tarjeta',
                      maxLines: 3,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SiteFormField(
                      icon: Icons.notes_outlined,
                      label: 'Descripción de índice',
                      iconColor: SiteFieldColors.orange,
                      controller: _indexDesc,
                      hintText: 'Descripción corta para el índice',
                      maxLines: 3,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SiteFormField(
                      icon: Icons.menu_book_outlined,
                      label: 'Resumen',
                      iconColor: SiteFieldColors.purple,
                      controller: _summary,
                      hintText: 'Resumen del programa',
                      maxLines: 4,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SiteImagePickerField(
                      newImage: _newImage,
                      existingImageUrl: existingImage,
                      onPick: _pickImage,
                      title: 'Imagen del programa',
                    ),
                    if (_isEditing) ...[
                      const SizedBox(height: AppSpacing.lg),
                      SiteDeleteButton(
                        label: 'Eliminar programa',
                        onPressed: _submitting ? null : _delete,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class ProgramLivePreview extends StatelessWidget {
  const ProgramLivePreview({super.key, required this.model});

  final ProgramModel model;

  @override
  Widget build(BuildContext context) {
    final accent = parseHexColor(model.accent) ?? const Color(0xFF2563EB);
    final foreground =
        ThemeData.estimateBrightnessForColor(accent) == Brightness.dark
            ? Colors.white
            : const Color(0xFF05070B);
    final option = ProgramIconOption.byValue(model.icon);
    final title =
        model.title.trim().isEmpty ? 'Nombre del programa' : model.title.trim();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: accent,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.26),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: foreground.withValues(alpha: 0.16),
            child: Icon(option.icon, color: foreground, size: 28),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: model.categories.take(3).map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: foreground.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(
                          color: foreground.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(
                          color: foreground,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ProgramColorPaletteField extends StatelessWidget {
  const ProgramColorPaletteField({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final Color selected;
  final ValueChanged<Color> onChanged;

  static const _palette = [
    Color(0xFF2563EB),
    Color(0xFF0F766E),
    Color(0xFF047857),
    Color(0xFF7C3AED),
    Color(0xFFC026D3),
    Color(0xFFBE123C),
    Color(0xFFB45309),
    Color(0xFF334155),
  ];

  Future<void> _openCustomPicker(BuildContext context) async {
    var picked = selected;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            top: AppSpacing.lg,
            bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Color personalizado',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: AppSpacing.md),
              ColorPicker(
                pickerColor: picked,
                onColorChanged: (color) => picked = color,
                paletteType: PaletteType.hsvWithHue,
                enableAlpha: false,
                labelTypes: const [],
                displayThumbColor: true,
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancelar'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Aplicar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed == true) {
      HapticFeedback.selectionClick();
      onChanged(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: SiteFieldColors.pink.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                ),
                child:
                    Icon(Icons.palette_outlined, color: SiteFieldColors.pink),
              ),
              const SizedBox(width: AppSpacing.md),
              const Expanded(
                child: Text(
                  'Color de identidad',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              TextButton.icon(
                onPressed: () => _openCustomPicker(context),
                icon: const Icon(Icons.tune, size: 18),
                label: const Text('Ajustar'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: _palette.map((color) {
              final active = color.toARGB32() == selected.toARGB32();
              return Tooltip(
                message: 'Elegir color',
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onChanged(color);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 42,
                    height: 42,
                    padding: EdgeInsets.all(active ? 4 : 2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: active
                            ? AppColors.textPrimary
                            : AppColors.surfaceBorder,
                        width: active ? 2.5 : 1,
                      ),
                    ),
                    child: CircleAvatar(backgroundColor: color),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class ProgramIconPickerField extends StatelessWidget {
  const ProgramIconPickerField({
    super.key,
    required this.selectedValue,
    required this.onChanged,
  });

  final String selectedValue;
  final ValueChanged<ProgramIconOption> onChanged;

  Future<void> _openPicker(BuildContext context) async {
    final selected = await showModalBottomSheet<ProgramIconOption>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
      ),
      builder: (_) => ProgramIconGridSheet(selectedValue: selectedValue),
    );
    if (selected == null) return;
    onChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    final selected = ProgramIconOption.byValue(selectedValue);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openPicker(context),
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.surfaceBorder),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: SiteFieldColors.green.withValues(alpha: 0.16),
                child: Icon(selected.icon, color: SiteFieldColors.green),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ícono del programa',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      selected.label,
                      style:
                          TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(Icons.expand_more, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class ProgramIconGridSheet extends StatefulWidget {
  const ProgramIconGridSheet({super.key, required this.selectedValue});

  final String selectedValue;

  @override
  State<ProgramIconGridSheet> createState() => _ProgramIconGridSheetState();
}

class _ProgramIconGridSheetState extends State<ProgramIconGridSheet> {
  final _search = TextEditingController();
  late List<ProgramIconOption> _filtered = ProgramIconOption.catalog;

  void _filter(String value) {
    final query = value.trim().toLowerCase();
    setState(() {
      _filtered = query.isEmpty
          ? ProgramIconOption.catalog
          : ProgramIconOption.catalog.where((option) {
              return option.label.toLowerCase().contains(query) ||
                  option.tags.any((tag) => tag.contains(query));
            }).toList();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.lg,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.74,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Elige un ícono',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _search,
                onChanged: _filter,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Buscar por tema: noticias, música, salud...',
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.bgBase,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                    borderSide: BorderSide(color: AppColors.surfaceBorder),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: GridView.builder(
                  itemCount: _filtered.length,
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 112,
                    mainAxisSpacing: AppSpacing.sm,
                    crossAxisSpacing: AppSpacing.sm,
                    childAspectRatio: 0.9,
                  ),
                  itemBuilder: (context, index) {
                    final option = _filtered[index];
                    final active = option.value == widget.selectedValue;
                    return InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        Navigator.of(context).pop(option);
                      },
                      borderRadius: BorderRadius.circular(AppRadius.chip),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: active
                              ? AppColors.accent.withValues(alpha: 0.14)
                              : AppColors.bgBase,
                          borderRadius: BorderRadius.circular(AppRadius.chip),
                          border: Border.all(
                            color: active
                                ? AppColors.accentStrong
                                : AppColors.surfaceBorder,
                            width: active ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(option.icon,
                                size: 28, color: AppColors.textPrimary),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              option.label,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProgramIconOption {
  const ProgramIconOption(this.value, this.label, this.icon, this.tags);

  final String value;
  final String label;
  final IconData icon;
  final List<String> tags;

  static const catalog = [
    ProgramIconOption(
        'radio', 'Radio', Icons.radio, ['radio', 'en vivo', 'live']),
    ProgramIconOption(
        'mic-2', 'Entrevistas', Icons.mic, ['entrevista', 'voz', 'podcast']),
    ProgramIconOption('music', 'Música', Icons.music_note,
        ['musica', 'canciones', 'playlist']),
    ProgramIconOption('newspaper', 'Noticias', Icons.newspaper,
        ['noticias', 'actualidad', 'news']),
    ProgramIconOption(
        'activity', 'Salud', Icons.favorite, ['salud', 'health', 'bienestar']),
    ProgramIconOption('dumbbell', 'Workout', Icons.fitness_center,
        ['workout', 'ejercicio', 'fitness']),
    ProgramIconOption('briefcase', 'Trabajo', Icons.business_center,
        ['trabajo', 'empresa', 'work']),
    ProgramIconOption('landmark', 'Finanzas', Icons.account_balance,
        ['finanzas', 'dinero', 'finance']),
    ProgramIconOption('graduation-cap', 'Educación', Icons.school,
        ['educacion', 'escuela', 'aprender']),
    ProgramIconOption('heart-handshake', 'Comunidad', Icons.groups,
        ['comunidad', 'social', 'ayuda']),
    ProgramIconOption('gamepad-2', 'Juegos', Icons.sports_esports,
        ['juegos', 'gaming', 'game']),
    ProgramIconOption(
        'utensils', 'Cocina', Icons.restaurant, ['cocina', 'comida', 'food']),
    ProgramIconOption('plane', 'Viajes', Icons.flight_takeoff,
        ['viajes', 'turismo', 'travel']),
    ProgramIconOption(
        'sparkles', 'Cultura', Icons.auto_awesome, ['cultura', 'arte', 'show']),
    ProgramIconOption('message-circle', 'Debate', Icons.forum,
        ['debate', 'opinion', 'charla']),
    ProgramIconOption('headphones', 'Podcast', Icons.headphones,
        ['podcast', 'audio', 'episodio']),
  ];

  static ProgramIconOption byValue(String value) => catalog.firstWhere(
        (option) => option.value == value,
        orElse: () => catalog.first,
      );
}

class ProgramTagManagerField extends StatefulWidget {
  const ProgramTagManagerField({
    super.key,
    required this.tags,
    required this.onChanged,
  });

  final List<String> tags;
  final ValueChanged<List<String>> onChanged;

  @override
  State<ProgramTagManagerField> createState() => _ProgramTagManagerFieldState();
}

class _ProgramTagManagerFieldState extends State<ProgramTagManagerField> {
  final _input = TextEditingController();
  static const _quickTags = [
    'Música',
    'Noticias',
    'Entrevista',
    'Comunidad',
    'Salud',
    'Deportes',
    'Cultura',
    'Finanzas',
  ];

  void _toggle(String tag) {
    final tags = List<String>.from(widget.tags);
    tags.contains(tag) ? tags.remove(tag) : tags.add(tag);
    HapticFeedback.selectionClick();
    widget.onChanged(tags);
  }

  void _addTypedTag() {
    final tag = _input.text.trim();
    if (tag.isEmpty) return;
    final tags = List<String>.from(widget.tags);
    if (!tags.any((current) => current.toLowerCase() == tag.toLowerCase())) {
      tags.add(tag);
    }
    _input.clear();
    widget.onChanged(tags);
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: SiteFieldColors.green.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                ),
                child: Icon(Icons.sell_outlined, color: SiteFieldColors.green),
              ),
              const SizedBox(width: AppSpacing.md),
              const Expanded(
                child: Text(
                  'Categorías',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: _quickTags.map((tag) {
              return FilterChip(
                label: Text(tag),
                selected: widget.tags.contains(tag),
                onSelected: (_) => _toggle(tag),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'Crear categoría',
                  ),
                  onSubmitted: (_) => _addTypedTag(),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              IconButton.filled(
                onPressed: _addTypedTag,
                icon: const Icon(Icons.add),
                tooltip: 'Agregar categoría',
              ),
            ],
          ),
          if (widget.tags.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: widget.tags.map((tag) {
                return InputChip(
                  label: Text(tag),
                  selected: true,
                  onDeleted:
                      widget.tags.length == 1 ? null : () => _toggle(tag),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _ScheduleSection extends StatelessWidget {
  const _ScheduleSection({required this.form});

  final ProgramFormController form;

  static const _days = [
    (value: 1, label: 'L'),
    (value: 2, label: 'M'),
    (value: 3, label: 'X'),
    (value: 4, label: 'J'),
    (value: 5, label: 'V'),
    (value: 6, label: 'S'),
    (value: 7, label: 'D'),
  ];

  Future<void> _pickHour(
    BuildContext context,
    int? current,
    ValueChanged<int?> onChanged,
  ) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ?? TimeOfDay.now().hour, minute: 0),
    );
    if (selected == null) return;
    onChanged(selected.hour);
  }

  @override
  Widget build(BuildContext context) {
    final model = form.model;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: SiteFieldColors.orange.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                ),
                child: Icon(Icons.schedule_outlined,
                    color: SiteFieldColors.orange),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Horario',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      model.schedule.isEmpty
                          ? 'Sin horario fijo'
                          : model.schedule,
                      style:
                          TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickHour(
                    context,
                    model.slotStart,
                    form.updateSlotStart,
                  ),
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: Text(model.slotStart == null
                      ? 'Inicio'
                      : '${model.slotStart!.toString().padLeft(2, '0')}:00'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickHour(
                    context,
                    model.slotEnd,
                    form.updateSlotEnd,
                  ),
                  icon: const Icon(Icons.stop, size: 18),
                  label: Text(model.slotEnd == null
                      ? 'Fin'
                      : '${model.slotEnd!.toString().padLeft(2, '0')}:00'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: _days.map((day) {
              final selected = model.weekdays.contains(day.value);
              return FilterChip(
                label: Text(day.label),
                selected: selected,
                onSelected: (value) {
                  final updated = Set<int>.from(model.weekdays);
                  value ? updated.add(day.value) : updated.remove(day.value);
                  form.updateWeekdays(updated);
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
