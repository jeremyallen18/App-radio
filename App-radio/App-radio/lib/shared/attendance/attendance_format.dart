// Formateadores compartidos por la pantalla "Mi asistencia" y sus tarjetas.

/// `90` -> `"1 h 30 min"`, `60` -> `"1 h"`, `20` -> `"20 min"`.
String attendanceMinutesLabel(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h > 0 && m > 0) return '$h h $m min';
  if (h > 0) return '$h h';
  return '$m min';
}

/// Duración como reloj `HH:MM:SS` (para el cronómetro de la hora de comida).
String attendanceClock(Duration d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
}
