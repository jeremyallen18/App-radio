// Pruebas del directorio de compañeros: cómo se leen las respuestas de
// /user/directory y /user/profile/{id}, y qué pinta cada componente nuevo del
// sistema de diseño. No tocan la red — las respuestas del backend van como
// mapas literales, igual que llegarían decodificadas.
//
// La cobertura de los endpoints en sí está en
// `tools/php-backend-test-directory.js`, que corre contra el backend real.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/models/models.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

Map<String, dynamic> _colleagueJson({
  String? position,
  String? managerEmail,
}) =>
    {
      'id': 'u1',
      'name': 'Ana Villalobos',
      'email': 'ana@radiodoliv.com',
      'role': 'employee',
      'position': position,
      'photoUrl': null,
      'department': {
        'id': 'd1',
        'companyId': 'c1',
        'name': 'Cabina',
        'description': 'Locución y aire',
        'managerEmail': managerEmail,
        'employeeCount': 6,
      },
    };

void main() {
  group('UserProfile del directorio', () {
    test('usa el puesto como línea principal cuando lo tiene', () {
      final user = UserProfile.fromJson(_colleagueJson(position: 'Locutora matutina'));
      expect(user.headline, 'Locutora matutina');
    });

    test('cae al rol cuando no hay puesto', () {
      final user = UserProfile.fromJson(_colleagueJson());
      expect(user.headline, 'Empleado');
    });

    test('reconoce a quien dirige su área, sin importar mayúsculas', () {
      final user = UserProfile.fromJson(
        _colleagueJson(managerEmail: 'ANA@radiodoliv.com'),
      );
      expect(user.leadsOwnDepartment, isTrue);
    });

    test('no marca como responsable a quien solo pertenece al área', () {
      final user = UserProfile.fromJson(_colleagueJson(managerEmail: 'otro@radiodoliv.com'));
      expect(user.leadsOwnDepartment, isFalse);
    });

    test('sin departamento no hay responsable que reconocer', () {
      final json = _colleagueJson()..['department'] = null;
      expect(UserProfile.fromJson(json).leadsOwnDepartment, isFalse);
    });
  });

  group('ColleagueProfile', () {
    test('lee perfil, equipos y antigüedad', () {
      final profile = ColleagueProfile.fromJson({
        ..._colleagueJson(position: 'Locutora matutina'),
        'teams': [
          {'id': 't1', 'teamName': 'Producción', 'isLeader': true},
          {'id': 't2', 'teamName': 'Aire', 'isLeader': false},
        ],
        'joinedAt': '2026-03-14 09:30:00',
      });

      expect(profile.user.name, 'Ana Villalobos');
      expect(profile.teams.map((t) => t.name), ['Producción', 'Aire']);
      expect(profile.teams.first.isLeader, isTrue);
      expect(profile.joinedAt?.year, 2026);
      expect(profile.joinedAt?.month, 3);
    });

    test('tolera una ficha sin equipos ni fecha', () {
      final profile = ColleagueProfile.fromJson(_colleagueJson());
      expect(profile.teams, isEmpty);
      expect(profile.joinedAt, isNull);
    });
  });

  group('Componentes de perfil', () {
    testWidgets('ProfileHeader muestra nombre, puesto e insignias', (tester) async {
      await tester.pumpWidget(_wrap(const ProfileHeader(
        name: 'Ana Villalobos',
        // La semilla del color es el correo, que aquí empieza con otra letra
        // a propósito: la inicial tiene que salir del nombre, no del correo.
        avatarSeed: 'zz.ana@radiodoliv.com',
        headline: 'Locutora matutina',
        badges: [AppBadge(label: 'Empleado', variant: AppBadgeVariant.info)],
      )));

      expect(find.text('Ana Villalobos'), findsOneWidget);
      expect(find.text('Locutora matutina'), findsOneWidget);
      expect(find.text('Empleado'), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('Z'), findsNothing);
    });

    testWidgets('ProfileHeader solo ofrece cambiar la foto si se lo piden', (tester) async {
      await tester.pumpWidget(_wrap(const ProfileHeader(
        name: 'Ana Villalobos',
        headline: 'Locutora matutina',
      )));
      expect(find.byIcon(Icons.photo_camera_outlined), findsNothing);

      await tester.pumpWidget(_wrap(ProfileHeader(
        name: 'Ana Villalobos',
        headline: 'Locutora matutina',
        onEditPhoto: () {},
      )));
      expect(find.byIcon(Icons.photo_camera_outlined), findsOneWidget);
    });

    testWidgets('PersonCard abre la ficha al tocarla', (tester) async {
      var opened = false;
      await tester.pumpWidget(_wrap(PersonCard(
        name: 'Marco Peña',
        avatarSeed: 'zz.marco@radiodoliv.com',
        headline: 'Técnico de audio',
        subtitle: 'Cabina',
        onTap: () => opened = true,
      )));

      expect(find.text('M'), findsOneWidget);
      expect(find.text('Marco Peña'), findsOneWidget);
      expect(find.text('Técnico de audio'), findsOneWidget);
      expect(find.text('Cabina'), findsOneWidget);

      await tester.tap(find.text('Marco Peña'));
      expect(opened, isTrue);
    });

    testWidgets('PersonCard sin acción no muestra el chevron', (tester) async {
      await tester.pumpWidget(_wrap(const PersonCard(
        name: 'Marco Peña',
        headline: 'Técnico de audio',
      )));
      expect(find.byIcon(Icons.chevron_right), findsNothing);
    });

    // La app es primero móvil: un nombre y un puesto largos no deben
    // desbordar la fila en una pantalla angosta (un desbordamiento de
    // RenderFlex hace fallar la prueba por sí solo).
    testWidgets('aguantan textos largos en una pantalla de teléfono', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrap(Column(
        children: const [
          ProfileHeader(
            name: 'María Fernanda de los Ángeles Villalobos Rentería',
            headline: 'Coordinadora de producción y continuidad de cabina',
            avatarSeed: 'maria.fernanda@radiodoliv.com',
            badges: [
              AppBadge(label: 'Manager de Departamento', variant: AppBadgeVariant.info),
              AppBadge(label: 'Producción y Continuidad'),
              AppBadge(label: 'Responsable del área', variant: AppBadgeVariant.success),
            ],
          ),
          PersonCard(
            name: 'María Fernanda de los Ángeles Villalobos Rentería',
            headline: 'Coordinadora de producción y continuidad de cabina',
            subtitle: 'Producción y Continuidad',
            badge: AppBadge(label: 'Responsable'),
          ),
        ],
      )));

      expect(tester.takeException(), isNull);
    });

    testWidgets('AppFilterChip muestra el conteo y avisa al seleccionarse', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_wrap(AppFilterChip(
        label: 'Mi área: Cabina',
        count: 6,
        selected: false,
        onTap: () => taps++,
      )));

      expect(find.text('Mi área: Cabina'), findsOneWidget);
      expect(find.text('6'), findsOneWidget);

      await tester.tap(find.text('Mi área: Cabina'));
      expect(taps, 1);
    });
  });
}
