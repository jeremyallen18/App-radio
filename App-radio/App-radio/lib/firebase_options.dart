// Generado a mano a partir de android/app/google-services.json.
// SOLO Android: iOS/web/Windows quedan fuera de alcance (ver spec 2026-09-06).
// Al pasar a la cuenta Firebase del cliente, regenerar SOLO estos valores.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Push no está configurado para web.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'Push solo está configurado para Android (plataforma actual: '
          '$defaultTargetPlatform).',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAPk_Nc1hhzS6RXLxpPz75BsMbnEFRNw64',
    appId: '1:2034974622:android:8374608ccf21b7d2db208f',
    messagingSenderId: '2034974622',
    projectId: 'doliv-test',
    storageBucket: 'doliv-test.firebasestorage.app',
  );
}
