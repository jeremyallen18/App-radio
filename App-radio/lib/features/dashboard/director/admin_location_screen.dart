import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/services/attendance_service.dart';
import 'package:doliv_social/core/location/attendance_location.dart';
import 'package:doliv_social/shared/calendar/location_picker_map.dart';

/// Configuración del lugar de asistencia (solo director). Define el punto y el
/// radio dentro del cual empleados y managers pueden registrar `entrada` y
/// `fin_comida`. Lo más simple: pararse en el lugar y tocar "Usar mi ubicación
/// actual"; también se puede escribir la latitud/longitud a mano o elegir el
/// punto sobre el mapa.
class AdminLocationScreen extends StatefulWidget {
  const AdminLocationScreen({super.key});

  @override
  State<AdminLocationScreen> createState() => _AdminLocationScreenState();
}

class _AdminLocationScreenState extends State<AdminLocationScreen> {
  final _lat = TextEditingController();
  final _lng = TextEditingController();
  final _radius = TextEditingController(text: '10');
  final _label = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _locating = false;
  String? _error;

  /// Precisión (m) del último lectura de GPS; `null` si el punto del mapa viene
  /// de la config guardada o de coordenadas escritas a mano.
  double? _accuracyM;

  @override
  void initState() {
    super.initState();
    _lat.addListener(_onCoordsChanged);
    _lng.addListener(_onCoordsChanged);
    _radius.addListener(_onCoordsChanged);
    _load();
  }

  @override
  void dispose() {
    _lat.dispose();
    _lng.dispose();
    _radius.dispose();
    _label.dispose();
    super.dispose();
  }

  void _onCoordsChanged() => setState(() {});

  /// Punto actualmente descrito por los campos, o `null` si aún no son válidos.
  LatLng? get _point {
    final lat = double.tryParse(_lat.text.trim());
    final lng = double.tryParse(_lng.text.trim());
    if (lat == null || lng == null) return null;
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
    return LatLng(lat, lng);
  }

  double get _radiusM {
    final r = double.tryParse(_radius.text.trim()) ?? 0;
    return r.clamp(1, 100000).toDouble();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await AttendanceApi.adminLocation();
      if (!mounted) return;
      setState(() {
        final loc = result.location;
        if (loc != null) {
          _lat.text = loc.latitude.toString();
          _lng.text = loc.longitude.toString();
          _radius.text = loc.radiusM.toString();
          _label.text = loc.label ?? '';
        }
        _loading = false;
      });
    } on AttendanceException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    try {
      final pos = await AttendanceLocation.current();
      if (!mounted) return;
      setState(() {
        _lat.text = pos.latitude.toStringAsFixed(7);
        _lng.text = pos.longitude.toStringAsFixed(7);
        _accuracyM = pos.accuracyM;
        _locating = false;
      });
    } on AttendanceException catch (e) {
      if (!mounted) return;
      setState(() => _locating = false);
      _snack(e.message);
    }
  }

  Future<void> _pickOnMap() async {
    final start = _point;
    final picked = await Navigator.of(context).push<({double lat, double lng})>(
      MaterialPageRoute(
        builder: (_) => LocationPickerMap(
          initialLatitude: start?.latitude,
          initialLongitude: start?.longitude,
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _lat.text = picked.lat.toStringAsFixed(7);
      _lng.text = picked.lng.toStringAsFixed(7);
      _accuracyM = null;
    });
  }

  Future<void> _save() async {
    final lat = double.tryParse(_lat.text.trim());
    final lng = double.tryParse(_lng.text.trim());
    final radius = int.tryParse(_radius.text.trim());
    if (lat == null || lng == null || lat < -90 || lat > 90 || lng < -180 || lng > 180) {
      setState(() => _error = 'Escribe una latitud y longitud válidas, o usa tu ubicación actual.');
      return;
    }
    if (radius == null || radius < 5 || radius > 1000) {
      setState(() => _error = 'El radio debe estar entre 5 y 1000 metros.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await AttendanceApi.saveLocation(
        latitude: lat,
        longitude: lng,
        radiusM: radius,
        label: _label.text,
      );
      if (!mounted) return;
      setState(() => _saving = false);
      _snack('Lugar de asistencia guardado correctamente');
    } on AttendanceException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.message;
      });
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Lugar de asistencia'),
      ),
      body: Builder(
        builder: (context) {
          if (_loading) return const LoadingState();
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.xxl,
            ),
            children: [
              const _HeroBanner(),
              const SizedBox(height: AppSpacing.lg),
              _RadiusMapPreview(
                point: _point,
                radiusM: _radiusM,
                accuracyM: _accuracyM,
                onOpenMap: _pickOnMap,
              ),
              const SizedBox(height: AppSpacing.xl),
              const _FieldLabel(
                icon: Icons.place_outlined,
                text: 'Nombre del lugar',
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                controller: _label,
                hintText: 'ej. Cabina Radio Doliv',
                prefixIcon: const Icon(Icons.apartment_outlined),
              ),
              const SizedBox(height: AppSpacing.xl),
              const _FieldLabel(
                icon: Icons.gps_fixed,
                text: 'Coordenadas',
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _captioned(
                      'Latitud',
                      AppTextField(
                        controller: _lat,
                        hintText: '19.1847179',
                        prefixIcon: const Icon(Icons.location_on_outlined),
                        textInputType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _captioned(
                      'Longitud',
                      AppTextField(
                        controller: _lng,
                        hintText: '-99.4322725',
                        prefixIcon: const Icon(Icons.location_on_outlined),
                        textInputType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              const _FieldLabel(
                icon: Icons.cell_tower,
                text: 'Radio permitido',
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _radius,
                      hintText: 'metros',
                      textInputType: TextInputType.number,
                      prefixIcon: const Icon(Icons.wifi_tethering),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  const _UnitSegment(label: 'm'),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
              ],
              const SizedBox(height: AppSpacing.xl),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _locating ? null : _useCurrentLocation,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                          textStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        icon: _locating
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.my_location, size: 18),
                        label: const Text(
                          'Usar mi ubicación actual',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _SaveButton(
                        loading: _saving,
                        onPressed: _saving ? null : _save,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Campo con una etiqueta corta encima, para que siga identificable una vez
  /// lleno (el hint desaparece al escribir).
  Widget _captioned(String label, Widget field) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: AppSpacing.xs),
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        field,
      ],
    );
  }
}

/// Aviso de contexto del encabezado: insignia circular con el pin, mensaje
/// principal y una segunda línea con la instrucción directa.
class _HeroBanner extends StatelessWidget {
  const _HeroBanner();

  @override
  Widget build(BuildContext context) {
    const accent = AppColors.accent;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: accent.withValues(alpha: 0.32)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.location_on, color: accent, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Los empleados y managers solo podrán registrar su entrada y '
                  'terminar su hora de comida si su teléfono está dentro de este '
                  'radio.',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: AppSpacing.sm),
                Text(
                  'Párate en el lugar y toca «Usar mi ubicación actual».',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Etiqueta de sección con ícono de acento a la izquierda.
class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.accent, size: 18),
        const SizedBox(width: AppSpacing.sm),
        Text(
          text,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ],
    );
  }
}

/// Segmento no interactivo con la unidad del radio ("m"), al estilo del
/// selector del concepto. El valor siempre se guarda en metros.
class _UnitSegment extends StatelessWidget {
  const _UnitSegment({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.field),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          const Icon(Icons.keyboard_arrow_down, color: AppColors.textMuted, size: 18),
        ],
      ),
    );
  }
}

/// Botón "Guardar lugar" con el degradado de marca y un ícono, en una fila
/// junto al botón outlined (no ocupa el ancho completo como [AppButton]).
class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.loading, required this.onPressed});

  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null && !loading;
    return AppPressable(
      enabled: enabled,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          gradient: AppColors.buttonGradient,
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: AppColors.brandBlue.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            onTap: enabled ? onPressed : null,
            child: Opacity(
              opacity: enabled ? 1 : 0.5,
              child: Center(
                child: loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppColors.textPrimary,
                        ),
                      )
                    : const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.save_outlined,
                              color: AppColors.textPrimary, size: 18),
                          SizedBox(width: AppSpacing.sm),
                          Text(
                            'Guardar lugar',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Vista previa del punto de asistencia sobre un mapa (OpenStreetMap), con el
/// radio permitido dibujado a escala y un marcador con halo. No es interactiva;
/// para mover el punto se abre el mapa completo con "Ver en mapa".
class _RadiusMapPreview extends StatefulWidget {
  const _RadiusMapPreview({
    required this.point,
    required this.radiusM,
    required this.accuracyM,
    required this.onOpenMap,
  });

  final LatLng? point;
  final double radiusM;
  final double? accuracyM;
  final VoidCallback onOpenMap;

  @override
  State<_RadiusMapPreview> createState() => _RadiusMapPreviewState();
}

class _RadiusMapPreviewState extends State<_RadiusMapPreview> {
  final MapController _map = MapController();

  static const double _height = 200;

  CameraFit? _fit(LatLng center) {
    final d = const Distance();
    final pad = (widget.radiusM * 1.7).clamp(25.0, 100000.0);
    final north = d.offset(center, pad, 0);
    final south = d.offset(center, pad, 180);
    final east = d.offset(center, pad, 90);
    final west = d.offset(center, pad, 270);
    return CameraFit.bounds(
      bounds: LatLngBounds(
        LatLng(north.latitude, west.longitude),
        LatLng(south.latitude, east.longitude),
      ),
      padding: const EdgeInsets.all(16),
    );
  }

  void _recenter() {
    final p = widget.point;
    if (p == null) return;
    final fit = _fit(p);
    if (fit != null) _map.fitCamera(fit);
  }

  @override
  void didUpdateWidget(_RadiusMapPreview old) {
    super.didUpdateWidget(old);
    final p = widget.point;
    if (p == null) return;
    if (old.point == null ||
        old.point != p ||
        old.radiusM != widget.radiusM) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _recenter();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final point = widget.point;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Container(
        height: _height,
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.surfaceBorder),
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: point == null
            ? const _MapPlaceholder()
            : Stack(
                children: [
                  Positioned.fill(
                    child: FlutterMap(
                      mapController: _map,
                      options: MapOptions(
                        initialCenter: point,
                        initialZoom: 16,
                        initialCameraFit: _fit(point),
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.none,
                        ),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.brl_task4',
                        ),
                        CircleLayer(
                          circles: [
                            CircleMarker(
                              point: point,
                              radius: widget.radiusM,
                              useRadiusInMeter: true,
                              color: AppColors.accent.withValues(alpha: 0.16),
                              borderColor:
                                  AppColors.accent.withValues(alpha: 0.9),
                              borderStrokeWidth: 2,
                            ),
                          ],
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: point,
                              width: 64,
                              height: 64,
                              child: const _PulseDot(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: AppSpacing.md,
                    top: AppSpacing.md,
                    child: _StatusChip(accuracyM: widget.accuracyM),
                  ),
                  Positioned(
                    right: AppSpacing.md,
                    top: AppSpacing.md,
                    child: Column(
                      children: [
                        _MapIconButton(
                          icon: Icons.near_me_outlined,
                          onTap: widget.onOpenMap,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _MapIconButton(
                          icon: Icons.my_location,
                          onTap: _recenter,
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: AppSpacing.md,
                    bottom: AppSpacing.md,
                    child: _MapPill(
                      icon: Icons.map_outlined,
                      label: 'Ver en mapa',
                      trailing: Icons.open_in_new,
                      onTap: widget.onOpenMap,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _MapPlaceholder extends StatelessWidget {
  const _MapPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map_outlined,
                color: AppColors.textMuted.withValues(alpha: 0.7), size: 28),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Toca «Usar mi ubicación actual» o escribe las coordenadas para '
              'ver el radio en el mapa.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chip flotante sobre el mapa: estado del punto y, si viene de GPS, su
/// precisión aproximada.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.accuracyM});

  final double? accuracyM;

  @override
  Widget build(BuildContext context) {
    final fromGps = accuracyM != null;
    final title = fromGps ? 'Tu ubicación actual' : 'Punto seleccionado';
    final subtitle = fromGps
        ? 'Aprox. ${accuracyM!.round()} m de precisión'
        : 'Confirma que el pin cae en el lugar correcto';
    return GlassPanel(
      radius: AppRadius.pill,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              fromGps ? Icons.gps_fixed : Icons.place_outlined,
              color: AppColors.accent,
              size: 16,
            ),
            const SizedBox(width: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 10.5),
                ),
              ],
            ),
            const SizedBox(width: AppSpacing.sm),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: fromGps ? AppColors.success : AppColors.textMuted,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapIconButton extends StatelessWidget {
  const _MapIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      radius: 12,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, color: AppColors.textPrimary, size: 18),
          ),
        ),
      ),
    );
  }
}

class _MapPill extends StatelessWidget {
  const _MapPill({
    required this.icon,
    required this.label,
    required this.trailing,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final IconData trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      radius: AppRadius.pill,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: AppColors.textPrimary, size: 16),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Icon(trailing, color: AppColors.textMuted, size: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Marcador central: punto blanco con un halo que late suavemente. Respeta la
/// preferencia de "reducir movimiento" (queda estático).
class _PulseDot extends StatefulWidget {
  const _PulseDot();

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  AnimationController? _c;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.reduceMotion) return;
    _c ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const dot = SizedBox(
      width: 18,
      height: 18,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: Color(0x66000000), blurRadius: 4, offset: Offset(0, 1)),
          ],
        ),
      ),
    );
    final controller = _c;
    if (controller == null) {
      return const Center(child: dot);
    }
    return Center(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          final t = controller.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: (1 - t) * 0.5,
                child: Container(
                  width: 18 + t * 42,
                  height: 18 + t * 42,
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              child!,
            ],
          );
        },
        child: dot,
      ),
    );
  }
}
