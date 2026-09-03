// Modelos de los anuncios internos de la empresa (Radio Doliv). Alimentados
// por /internal-announcements del backend PHP
// (hive-backend/internal_announcements.php).
//
// El DIRECTOR publica un anuncio y TODA la audiencia lo recibe de inmediato
// (no hay ventana de vigencia). Puede ser 'general' o por áreas. El resto lo
// ve en su tablero de inicio y, si el anuncio lo pide (una reunión), confirma
// asistencia; al confirmar "sí" recibe recordatorios recurrentes hasta la
// reunión. El director consulta el historial de visualizaciones y
// confirmaciones.

/// Un departamento al que va dirigido un anuncio por áreas.
class AnnouncementArea {
  final String id;
  final String name;

  const AnnouncementArea({required this.id, required this.name});

  factory AnnouncementArea.fromJson(Map<String, dynamic> json) => AnnouncementArea(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
      );
}

class InternalAnnouncement {
  final String id;
  final String title;
  final String body;
  final String scope; // 'general' | 'areas'
  final bool requiresConfirmation;
  final DateTime? eventAt;
  final String? locationLabel;
  final bool active;
  final DateTime? createdAt;
  final List<AnnouncementArea> areas;

  // Estado personal del usuario que consulta (no director).
  final bool viewedByMe;
  final String? myConfirmation; // 'si' | 'no' | null

  // Agregados que solo llegan al director.
  final int? viewCount;
  final int? confirmedYes;
  final int? confirmedNo;
  final int? audienceCount;

  const InternalAnnouncement({
    required this.id,
    required this.title,
    required this.body,
    required this.scope,
    required this.requiresConfirmation,
    required this.eventAt,
    required this.locationLabel,
    required this.active,
    required this.createdAt,
    required this.areas,
    required this.viewedByMe,
    required this.myConfirmation,
    required this.viewCount,
    required this.confirmedYes,
    required this.confirmedNo,
    required this.audienceCount,
  });

  bool get isGeneral => scope != 'areas';

  String get areaNames => areas.map((a) => a.name).join(', ');

  /// Reunión con fecha ya pasada (más de un día). El backend además la excluye
  /// del tablero del resto de la plantilla.
  bool get isFinished =>
      eventAt != null &&
      DateTime.now().isAfter(eventAt!.add(const Duration(days: 1)));

  factory InternalAnnouncement.fromJson(Map<String, dynamic> json) {
    return InternalAnnouncement(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      scope: json['scope']?.toString() ?? 'general',
      requiresConfirmation: json['requiresConfirmation'] == true,
      eventAt: json['eventAt'] != null
          ? DateTime.tryParse(json['eventAt'].toString())
          : null,
      locationLabel: json['locationLabel']?.toString(),
      active: json['active'] == true,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      areas: ((json['areas'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => AnnouncementArea.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      viewedByMe: json['viewedByMe'] == true,
      myConfirmation: json['myConfirmation']?.toString(),
      viewCount: (json['viewCount'] as num?)?.toInt(),
      confirmedYes: (json['confirmedYes'] as num?)?.toInt(),
      confirmedNo: (json['confirmedNo'] as num?)?.toInt(),
      audienceCount: (json['audienceCount'] as num?)?.toInt(),
    );
  }
}

/// Una fila del historial de visualizaciones/confirmaciones (vista del director).
class AnnouncementViewer {
  final String userId;
  final String name;
  final String email;
  final String? departmentName;
  final DateTime? viewedAt;
  final String? confirmation; // 'si' | 'no' | null
  final DateTime? respondedAt;

  const AnnouncementViewer({
    required this.userId,
    required this.name,
    required this.email,
    required this.departmentName,
    required this.viewedAt,
    required this.confirmation,
    required this.respondedAt,
  });

  bool get hasViewed => viewedAt != null;

  factory AnnouncementViewer.fromJson(Map<String, dynamic> json) => AnnouncementViewer(
        userId: json['userId']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        email: json['email']?.toString() ?? '',
        departmentName: json['departmentName']?.toString(),
        viewedAt: json['viewedAt'] != null
            ? DateTime.tryParse(json['viewedAt'].toString())
            : null,
        confirmation: json['confirmation']?.toString(),
        respondedAt: json['respondedAt'] != null
            ? DateTime.tryParse(json['respondedAt'].toString())
            : null,
      );
}

/// Respuesta de GET /internal-announcements/{id}/views.
class AnnouncementViewsReport {
  final String title;
  final bool requiresConfirmation;
  final List<AnnouncementViewer> viewers;
  final int viewCount;
  final int confirmedYes;
  final int confirmedNo;
  final int audienceCount;

  const AnnouncementViewsReport({
    required this.title,
    required this.requiresConfirmation,
    required this.viewers,
    required this.viewCount,
    required this.confirmedYes,
    required this.confirmedNo,
    required this.audienceCount,
  });

  factory AnnouncementViewsReport.fromJson(Map<String, dynamic> json) => AnnouncementViewsReport(
        title: json['title']?.toString() ?? '',
        requiresConfirmation: json['requiresConfirmation'] == true,
        viewers: ((json['viewers'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => AnnouncementViewer.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        viewCount: (json['viewCount'] as num?)?.toInt() ?? 0,
        confirmedYes: (json['confirmedYes'] as num?)?.toInt() ?? 0,
        confirmedNo: (json['confirmedNo'] as num?)?.toInt() ?? 0,
        audienceCount: (json['audienceCount'] as num?)?.toInt() ?? 0,
      );
}
