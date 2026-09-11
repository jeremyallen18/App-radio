import 'package:flutter/material.dart';

import 'package:doliv_social/core/api_config.dart';

/// Un programa de la parrilla (`GET /radio/programs`, tabla `radio_programs`
/// compartida con RADIODOLIV_PAGINA).
class RadioProgram {
  final int id;
  final String title;
  final String? host;

  /// Etiqueta legible del horario, ej. "Lunes a Viernes | 9:00 AM - 11:00 AM".
  final String? schedule;

  /// Etiqueta corta de la franja, ej. "9:00 - 11:00 AM".
  final String? badgeTime;

  /// Hora de inicio / fin de la franja (0-23). Puede ser `null`.
  final int? slotStart;
  final int? slotEnd;

  /// Días en que se emite, en formato ISO (1 = lunes … 7 = domingo).
  final Set<int> weekdays;

  final Color? accentColor;
  final String? imageUrl;

  RadioProgram({
    required this.id,
    required this.title,
    required this.host,
    required this.schedule,
    required this.badgeTime,
    required this.slotStart,
    required this.slotEnd,
    required this.weekdays,
    required this.accentColor,
    required this.imageUrl,
  });

  factory RadioProgram.fromJson(Map<String, dynamic> json) {
    final rawImage = json['image']?.toString();
    return RadioProgram(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: json['title']?.toString() ?? 'Programa',
      host: json['host']?.toString(),
      schedule: json['schedule']?.toString(),
      badgeTime: json['badgeTime']?.toString(),
      slotStart: (json['slotStart'] as num?)?.toInt(),
      slotEnd: (json['slotEnd'] as num?)?.toInt(),
      weekdays: ((json['weekdays'] as List?) ?? const [])
          .map((e) => (e as num?)?.toInt() ?? 0)
          .where((n) => n >= 1 && n <= 7)
          .toSet(),
      accentColor: _parseHex(json['accent']?.toString()),
      imageUrl: (rawImage == null || rawImage.isEmpty)
          ? null
          : (rawImage.startsWith('http') ? rawImage : kSiteBaseUrl + rawImage),
    );
  }

  /// `true` si el programa se emite el día [isoWeekday] (1 = lunes … 7 = domingo).
  bool airsOn(int isoWeekday) =>
      weekdays.isEmpty || weekdays.contains(isoWeekday);

  /// `true` si está al aire ahora mismo (día + hora dentro de la franja).
  bool isOnAirNow([DateTime? now]) {
    final n = now ?? DateTime.now();
    final s = slotStart, e = slotEnd;
    if (s == null || e == null) return false;
    final overnight = e <= s;
    final scheduleWeekday = overnight && n.hour < e
        ? (n.weekday == DateTime.monday ? DateTime.sunday : n.weekday - 1)
        : n.weekday;
    if (!airsOn(scheduleWeekday)) return false;
    return overnight
        ? (n.hour >= s || n.hour < e)
        : (n.hour >= s && n.hour < e);
  }

  String get timeLabel =>
      badgeTime ??
      (slotStart != null && slotEnd != null
          ? '${slotStart!.toString().padLeft(2, '0')}:00 - ${slotEnd!.toString().padLeft(2, '0')}:00'
          : (schedule ?? ''));

  static Color? _parseHex(String? hex) {
    if (hex == null) return null;
    var h = hex.replaceAll('#', '').trim();
    if (h.length == 6) h = 'FF$h';
    if (h.length != 8) return null;
    final v = int.tryParse(h, radix: 16);
    return v == null ? null : Color(v);
  }
}
