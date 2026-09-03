// Modelos del calendario (Radio Doliv). Alimentados por GET /calendar y
// GET /events del backend PHP (hive-backend/events.php).
//
// - CalendarActivity: una tarea a entregar (tabla `tasks`) con fecha límite.
// - CalendarEvent: un evento creado por el director, 'general' o por áreas.
//   Si `hasLocation`, ese día sustituye el lugar y la hora de ENTRADA de
//   asistencia para los miembros de las áreas asignadas.

class CalendarActivity {
  final String description;
  final DateTime? deadline;
  final bool completed;
  final String assignedTo;
  final String? teamName;
  final String? domainName;

  CalendarActivity({
    required this.description,
    required this.deadline,
    required this.completed,
    required this.assignedTo,
    this.teamName,
    this.domainName,
  });

  factory CalendarActivity.fromJson(Map<String, dynamic> json) => CalendarActivity(
        description: json['description']?.toString() ?? '',
        deadline: DateTime.tryParse(json['deadline']?.toString() ?? ''),
        completed: json['completed'] == true,
        assignedTo: json['assignedTo']?.toString() ?? '',
        teamName: json['teamName']?.toString(),
        domainName: json['domainName']?.toString(),
      );
}

/// Un departamento asignado a un evento.
class EventArea {
  final String id;
  final String name;

  EventArea({required this.id, required this.name});

  factory EventArea.fromJson(Map<String, dynamic> json) =>
      EventArea(id: json['id']?.toString() ?? '', name: json['name']?.toString() ?? '');
}

class CalendarEvent {
  final String id;
  final String title;
  final String? description;
  final DateTime date;
  final String? startTime; // "HH:MM"
  final String? endTime;
  final String scope; // 'general' | 'areas'
  final bool hasLocation;
  final double? latitude;
  final double? longitude;
  final int? radiusM;
  final String? locationLabel;

  /// Lugar del evento en texto libre (independiente de la geocerca).
  final String? locationText;

  /// Días de antelación de los recordatorios automáticos (7/5/3/2).
  final List<int> reminderOffsets;

  final String? entryTime; // "HH:MM" — override de hora de entrada
  final List<EventArea> areas;

  CalendarEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.scope,
    required this.hasLocation,
    required this.latitude,
    required this.longitude,
    required this.radiusM,
    required this.locationLabel,
    this.locationText,
    this.reminderOffsets = const [7, 5, 3, 2],
    required this.entryTime,
    required this.areas,
  });

  bool get isGeneral => scope != 'areas';

  String get areaNames => areas.map((a) => a.name).join(', ');

  factory CalendarEvent.fromJson(Map<String, dynamic> json) => CalendarEvent(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        description: json['description']?.toString(),
        date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
        startTime: json['startTime']?.toString(),
        endTime: json['endTime']?.toString(),
        scope: json['scope']?.toString() ?? 'general',
        hasLocation: json['hasLocation'] == true,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        radiusM: (json['radiusM'] as num?)?.toInt(),
        locationLabel: json['locationLabel']?.toString(),
        locationText: (json['locationText']?.toString().isNotEmpty ?? false)
            ? json['locationText'].toString()
            : null,
        reminderOffsets: ((json['reminderOffsets'] as List?) ?? const [7, 5, 3, 2])
            .map((e) => (e as num).toInt())
            .toList(),
        entryTime: json['entryTime']?.toString(),
        areas: ((json['areas'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => EventArea.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

/// Evento con ubicación que hoy sustituye el lugar y la hora de ENTRADA de
/// asistencia del trabajador. Lo devuelve GET /attendance/today
/// (campo `entryOverrideEvent`).
class EntryOverrideEvent {
  final String title;
  final String? entryTime; // "HH:MM"
  final double latitude;
  final double longitude;
  final int radiusM;
  final String? label;

  EntryOverrideEvent({
    required this.title,
    required this.entryTime,
    required this.latitude,
    required this.longitude,
    required this.radiusM,
    required this.label,
  });

  static EntryOverrideEvent? maybe(dynamic json) {
    if (json is! Map) return null;
    final loc = json['location'];
    if (loc is! Map) return null;
    return EntryOverrideEvent(
      title: json['title']?.toString() ?? 'Evento',
      entryTime: json['entryTime']?.toString(),
      latitude: (loc['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (loc['longitude'] as num?)?.toDouble() ?? 0,
      radiusM: (loc['radiusM'] as num?)?.toInt() ?? 50,
      label: loc['label']?.toString(),
    );
  }
}
