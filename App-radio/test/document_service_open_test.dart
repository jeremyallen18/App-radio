// Cubre las piezas puras de `DocumentService` para abrir un documento en el
// visor nativo: el mensaje de error y el saneado del nombre de archivo.

import 'package:flutter_test/flutter_test.dart';
import 'package:doliv_social/services/document_service.dart';

void main() {
  test('DocumentException expone el mensaje tal cual', () {
    expect(
      DocumentException('El archivo ya no está disponible.').toString(),
      'El archivo ya no está disponible.',
    );
  });

  test('sanitizeFileName reemplaza los caracteres inválidos de nombre de archivo',
      () {
    expect(
      DocumentService.sanitizeFileName('a/b:c*?"<>|.pdf'),
      'a_b_c______.pdf',
    );
    expect(DocumentService.sanitizeFileName('informe final.docx'),
        'informe final.docx');
  });
}
