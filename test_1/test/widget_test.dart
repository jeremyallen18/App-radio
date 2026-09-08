// Smoke test básico del clon recortado: la app arranca y muestra el registro.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:doliv_social/main.dart';

void main() {
  testWidgets('La app arranca sin sesión y renderiza', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp(hasSession: false));
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
