/// La empresa (Radio Doliv). Solo existe un registro; lo crea el director la
/// primera vez que entra. Lo alimentan `GET /company/info` y
/// `POST /company/create`, que devuelven la fila tal cual (claves snake_case).
class Company {
  final String id;
  final String name;
  final String? description;
  final String? logo;
  final DateTime? createdAt;

  const Company({
    required this.id,
    required this.name,
    this.description,
    this.logo,
    this.createdAt,
  });

  factory Company.fromJson(Map<String, dynamic> json) {
    return Company(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      logo: json['logo'] as String?,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }
}
