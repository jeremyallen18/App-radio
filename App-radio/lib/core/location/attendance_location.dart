import 'package:geolocator/geolocator.dart';

import 'package:doliv_social/services/attendance_service.dart' show AttendanceException;

/// Obtiene la ubicación actual del dispositivo para verificar el lugar de
/// asistencia. Pide el permiso si hace falta y traduce cualquier problema a
/// un [AttendanceException] con mensaje en español listo para mostrar.
///
/// Se llama SOLO al registrar entrada o al terminar la hora de comida — nunca
/// se rastrea la ubicación de forma continua.
class AttendanceLocation {
  static Future<({double latitude, double longitude, double accuracyM})>
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
      );
    } catch (_) {
      throw AttendanceException(
        'No fue posible obtener tu ubicación. Sal a un lugar con mejor señal e '
        'inténtalo de nuevo.',
      );
    }
  }
}
