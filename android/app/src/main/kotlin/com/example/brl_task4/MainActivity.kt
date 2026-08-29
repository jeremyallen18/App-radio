package com.example.brl_task4

import com.ryanheise.audioservice.AudioServiceActivity

// just_audio_background / audio_service requieren que la Activity principal
// herede de AudioServiceActivity (en vez de FlutterActivity a secas) para
// poder conectar el foreground service de audio con el motor de Flutter.
// Sin esto, el reproductor lanza: "The Activity class declared in your
// AndroidManifest.xml is wrong or has not provided the correct
// FlutterEngine."
class MainActivity: AudioServiceActivity() {
}
