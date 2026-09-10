/// La empresa (registro único; lo crea el director). `GET /company/info` /
/// `POST /company/create` devuelven la fila tal cual (snake_case).
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
