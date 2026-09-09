// Cubre la derivación de extensión que usa el visor de imágenes para nombrar
// el archivo al descargarlo.

import 'package:flutter_test/flutter_test.dart';
import 'package:doliv_social/shared/resources/imagecc.dart';

void main() {
  test('imageExtFromUrl reconoce extensiones válidas y cae a jpg', () {
    expect(imageExtFromUrl('https://x/y/foto.PNG'), 'png');
    expect(imageExtFromUrl('https://x/y/foto.webp?v=2'), 'webp');
    expect(imageExtFromUrl('https://x/y/foto.jpeg'), 'jpeg');
    expect(imageExtFromUrl('https://x/y/sin-extension'), 'jpg');
    expect(imageExtFromUrl('https://x/y/archivo.bmp'), 'jpg');
    expect(imageExtFromUrl('https://x/y/termina.con.punto.'), 'jpg');
  });
}
