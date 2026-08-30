import 'package:flutter/material.dart';

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/models/attendance.dart';
import 'package:doliv_social/services/attendance_service.dart';
import 'package:doliv_social/core/location/attendance_location.dart';

/// Configuración del lugar de asistencia (solo director). Define el punto y el
/// radio dentro del cual empleados y managers pueden registrar `entrada` y
/// `fin_comida`. Lo más simple: pararse en el lugar y tocar "Usar mi ubicación
/// actual"; también se puede escribir la latitud/longitud a mano.
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
  AttendanceLocationConfig? _current;

  @override
  void initState() {
    super.initState();
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

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await AttendanceApi.adminLocation();
      if (!mounted) return;
      setState(() {
        _current = result.location;
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
        _locating = false;
      });
    } on AttendanceException catch (e) {
      if (!mounted) return;
      setState(() => _locating = false);
      _snack(e.message);
    }
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
      final saved = await AttendanceApi.saveLocation(
        latitude: lat,
        longitude: lng,
        radiusM: radius,
        label: _label.text,
      );
      if (!mounted) return;
      setState(() {
        _current = saved;
        _saving = false;
      });
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
        leading: const AppBackButton(),
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
              const Text(
                'Los empleados y managers solo podrán registrar su entrada y '
                'terminar su hora de comida si su teléfono está dentro de este '
                'radio. Párate en el lugar y toca "Usar mi ubicación actual".',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_current != null)
                AppCard(
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline, color: AppColors.success),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          'Configurado: ${_current!.latitude.toStringAsFixed(5)}, '
                          '${_current!.longitude.toStringAsFixed(5)} · radio '
                          '${_current!.radiusM} m',
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton.icon(
                onPressed: _locating ? null : _useCurrentLocation,
                icon: _locating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location),
                label: const Text('Usar mi ubicación actual'),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                controller: _label,
                hintText: 'Nombre del lugar (ej. Cabina Radio Doliv)',
                prefixIcon: const Icon(Icons.badge_outlined),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _lat,
                      hintText: 'Latitud',
                      textInputType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppTextField(
                      controller: _lng,
                      hintText: 'Longitud',
                      textInputType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _radius,
                hintText: 'Radio permitido (metros)',
                textInputType: TextInputType.number,
                prefixIcon: const Icon(Icons.social_distance_outlined),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
              ],
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: 'GUARDAR LUGAR',
                loading: _saving,
                onPressed: _saving ? null : _save,
              ),
            ],
          );
        },
      ),
    );
  }
}
