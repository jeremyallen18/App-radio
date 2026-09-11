import 'package:geolocator/geolocator.dart';

import 'package:doliv_social/services/attendance_service.dart' show AttendanceException;

/// Ubicación actual para verificar el lugar de asistencia: pide permiso y
/// traduce los fallos a [AttendanceException] en español. Solo se llama al
/// fichar entrada o fin de comida; nunca hay rastreo continuo.
class AttendanceLocation {
  static Future<({
    double latitude,
    double longitude,
    double accuracyM,
    bool isMocked,
  })>
      current() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw AttendanceException(
        'Activa la ubicación (GPS) del dispositivo para registrar tu asistencia.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw AttendanceException(
        'El permiso de ubicación está bloqueado. Actívalo en los ajustes de la '
        'app para poder registrar tu asistencia.',
      );
    }
    if (permission == LocationPermission.denied) {
      throw AttendanceException(
        'Necesitamos tu ubicación para verificar que estás en el lugar de '
        'trabajo. Concede el permiso e inténtalo de nuevo.',
      );
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      return (
        latitude: pos.latitude,
        longitude: pos.longitude,
        accuracyM: pos.accuracy,
        isMocked: pos.isMocked,
      );
    } catch (_) {
      throw AttendanceException(
        'No fue posible obtener tu ubicación. Sal a un lugar con mejor señal e '
        'inténtalo de nuevo.',
      );
    }
  }
}
