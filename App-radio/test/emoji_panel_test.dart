// Regresión: el panel de emojis de la app NO debe contener ningún campo de
// texto. Un TextField dentro del panel abre el teclado del sistema (con su
// propia rejilla de emojis) encima del panel, y quedan DOS teclados de emojis
// a la vez — justo lo que se debe evitar (ver chat / MessageComposer).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:doliv_social/design/components/emoji_picker_panel.dart';

void main() {
  Widget host(void Function(String) onPick) => MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const Spacer(),
              EmojiPickerPanel(onEmojiSelected: onPick),
            ],
          ),
        ),
      );

  testWidgets('el panel no tiene ningún campo de texto (no abre el teclado del sistema)',
      (tester) async {
    await tester.pumpWidget(host((_) {}));
    await tester.pumpAndSettle();

    expect(find.byType(EditableText), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('tocar el panel nunca solicita el teclado del sistema',
      (tester) async {
    // Registramos cualquier llamada al canal de texto: si algo pidiera el IME
    // (TextInput.setClient / TextInput.show), lo detectaríamos aquí.
    final textInputCalls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.textInput,
      (call) async {
        textInputCalls.add(call.method);
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.textInput, null);
    });

    await tester.pumpWidget(host((_) {}));
    await tester.pumpAndSettle();

    // Tocar donde antes vivía el buscador (arriba del panel) y una pestaña.
    await tester.tap(find.text('Gestos'));
    await tester.pumpAndSettle();
    await tester.tapAt(tester.getCenter(find.byType(EmojiPickerPanel)).translate(0, -110));
    await tester.pumpAndSettle();

    expect(
      textInputCalls.where((m) => m.contains('show') || m.contains('setClient')),
      isEmpty,
      reason: 'el panel de emojis no debe invocar el teclado del sistema',
    );
  });

  testWidgets('sigue permitiendo elegir un emoji', (tester) async {
    String? picked;
    await tester.pumpWidget(host((e) => picked = e));
    await tester.pumpAndSettle();

    // Primer emoji de la categoría "Caritas".
    await tester.tap(find.text('\u{1F600}').first);
    await tester.pumpAndSettle();

    expect(picked, '\u{1F600}');
  });
}
