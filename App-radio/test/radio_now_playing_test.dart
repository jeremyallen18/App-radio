// El renglón "qué suena" del reproductor muestra el título ICY del stream de
// Zeno.fm cuando existe; si no llega ninguno, cae al nombre del programa al
// aire. Aquí se prueban las dos funciones puras que deciden ese texto.

import 'package:flutter_test/flutter_test.dart';

import 'package:doliv_social/core/audio/radio_player.dart';
import 'package:doliv_social/shared/radio/radio_player_sheet.dart';

void main() {
  group('radioStatusLine', () {
    test('el título ICY manda cuando existe', () {
      expect(
        radioStatusLine(
          nowPlaying: 'Zoé - Luna',
          onAirProgramTitle: 'La Mañanera',
          onAirProgramHost: 'Ana',
          active: true,
        ),
        'Zoé - Luna',
      );
    });

    test('sin título ICY y sonando, muestra el programa al aire con locutor', () {
      expect(
        radioStatusLine(
          nowPlaying: null,
          onAirProgramTitle: 'La Mañanera',
          onAirProgramHost: 'Ana',
          active: true,
        ),
        'La Mañanera · con Ana',
      );
    });

    test('programa al aire sin locutor: solo el título', () {
      expect(
        radioStatusLine(
          nowPlaying: null,
          onAirProgramTitle: 'La Mañanera',
          onAirProgramHost: null,
          active: true,
        ),
        'La Mañanera',
      );
    });

    test('sin título ICY ni programa, pero sonando: "Transmisión en vivo"', () {
      expect(
        radioStatusLine(
          nowPlaying: null,
          onAirProgramTitle: null,
          onAirProgramHost: null,
          active: true,
        ),
        'Transmisión en vivo',
      );
    });

    test('detenida: "Fuera del aire" aunque haya programa en la parrilla', () {
      expect(
        radioStatusLine(
          nowPlaying: null,
          onAirProgramTitle: 'La Mañanera',
          onAirProgramHost: 'Ana',
          active: false,
        ),
        'Fuera del aire',
      );
    });
  });

  group('normalizeIcyTitle', () {
    test('conserva un título real', () {
      expect(normalizeIcyTitle('Café Tacvba - Eres'), 'Café Tacvba - Eres');
    });

    test('recorta los espacios sobrantes', () {
      expect(normalizeIcyTitle('  Zoé - Luna  '), 'Zoé - Luna');
    });

    test('trata un guion suelto como sin metadatos', () {
      expect(normalizeIcyTitle('-'), isNull);
      expect(normalizeIcyTitle(' - '), isNull);
      expect(normalizeIcyTitle('--'), isNull);
      expect(normalizeIcyTitle('—'), isNull);
    });

    test('trata cadena vacía o nula como sin metadatos', () {
      expect(normalizeIcyTitle(''), isNull);
      expect(normalizeIcyTitle('   '), isNull);
      expect(normalizeIcyTitle(null), isNull);
    });
  });
}
