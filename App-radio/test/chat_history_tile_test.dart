// Regresión: la fila de la bandeja de Mensajes (ListTile con avatar y badge
// de no leídos como `trailing`) debe montar sin excepciones de layout. Un
// `trailing` que se expande a todo el ancho hace que el ListTile aborte con
// "Trailing widget consumes entire tile width" y la lista se rompa en cadena.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:doliv_social/design/design.dart';

void main() {
  testWidgets('ListTile con UnreadCountBadge en trailing se dibuja', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
        body: ListView(
          children: [
            ListTile(
              leading: const IdentityAvatar(id: 'ana@doliv.test', radius: 20),
              title: const Text('Ana'),
              subtitle: const Text('Tú: nos vemos en cabina'),
              trailing: const UnreadCountBadge(count: 3),
              onTap: () {},
            ),
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('3'), findsOneWidget);
  });
}
