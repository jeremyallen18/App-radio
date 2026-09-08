// La empresa se lee de `GET /company/info` / `POST /company/create`, que
// devuelven la fila tal cual (claves snake_case, incl. `created_at`).

import 'package:flutter_test/flutter_test.dart';

import 'package:doliv_social/models/company.dart';

void main() {
  test('Company.fromJson lee la fila snake_case del backend', () {
    final c = Company.fromJson({
      'id': 'c1abc',
      'name': 'Radio Doliv',
      'description': 'Estación de radio',
      'logo': null,
      'created_at': '2026-09-08 11:16:57',
    });

    expect(c.id, 'c1abc');
    expect(c.name, 'Radio Doliv');
    expect(c.description, 'Estación de radio');
    expect(c.logo, isNull);
    expect(c.createdAt, DateTime.tryParse('2026-09-08 11:16:57'));
  });

  test('Company.fromJson tolera description/logo/created_at ausentes', () {
    final c = Company.fromJson({'id': 'c2', 'name': 'Otra'});

    expect(c.id, 'c2');
    expect(c.name, 'Otra');
    expect(c.description, isNull);
    expect(c.logo, isNull);
    expect(c.createdAt, isNull);
  });
}
