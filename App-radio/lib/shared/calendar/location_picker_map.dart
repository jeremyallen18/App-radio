import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/core/location/attendance_location.dart';
import 'package:doliv_social/services/attendance_service.dart' show AttendanceException;

/// Selector de ubicación sobre un mapa (OpenStreetMap). Se toca el mapa para
/// fijar el punto; el botón "Usar mi ubicación" centra el mapa en el GPS.
/// Devuelve `({double lat, double lng})` con `Navigator.pop`, o `null` si se
/// cancela.
class LocationPickerMap extends StatefulWidget {
  const LocationPickerMap({super.key, this.initialLatitude, this.initialLongitude});

  final double? initialLatitude;
  final double? initialLongitude;

  @override
  State<LocationPickerMap> createState() => _LocationPickerMapState();
}

class _LocationPickerMapState extends State<LocationPickerMap> {
  final MapController _controller = MapController();

  // Centro por defecto: Radio Doliv (Cuernavaca, MX) si no llega nada.
  static const LatLng _fallback = LatLng(18.9186, -99.2342);

  late LatLng _picked = (widget.initialLatitude != null && widget.initialLongitude != null)
      ? LatLng(widget.initialLatitude!, widget.initialLongitude!)
      : _fallback;

  bool _locating = false;

  Future<void> _useMyLocation() async {
    setState(() => _locating = true);
    try {
      final pos = await AttendanceLocation.current();
      final here = LatLng(pos.latitude, pos.longitude);
      setState(() => _picked = here);
      _controller.move(here, 16);
    } on AttendanceException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      padding: EdgeInsets.zero,
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Ubicación del evento'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(
              (lat: _picked.latitude, lng: _picked.longitude),
            ),
            child: const Text('Usar este punto'),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _controller,
            options: MapOptions(
              initialCenter: _picked,
              initialZoom: 15,
              onTap: (_, latlng) => setState(() => _picked = latlng),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.brl_task4',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _picked,
                    width: 44,
                    height: 44,
                    alignment: Alignment.topCenter,
                    child: const Icon(Icons.location_on, color: AppColors.accent, size: 44),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            bottom: AppSpacing.lg,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppCard(
                  child: Row(
                    children: [
                      const Icon(Icons.place_outlined, color: AppColors.accent, size: 18),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Lat ${_picked.latitude.toStringAsFixed(6)},  '
                          'Lng ${_picked.longitude.toStringAsFixed(6)}',
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppButton(
                  label: 'Usar mi ubicación',
                  loading: _locating,
                  onPressed: _locating ? null : _useMyLocation,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
