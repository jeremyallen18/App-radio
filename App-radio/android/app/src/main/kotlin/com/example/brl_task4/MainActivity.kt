package com.example.brl_task4

import com.ryanheise.audioservice.AudioServiceFragmentActivity

// AudioServiceFragmentActivity = FlutterFragmentActivity (que exige local_auth
// para poder mostrar el prompt nativo de biometría/PIN) MÁS el wiring que
// audio_service / just_audio_background necesitan para conectar el foreground
// service de audio con el motor de Flutter.
//
// Con FlutterFragmentActivity a secas, JustAudioBackground.init() y la
// reproducción de la radio lanzaban: "The Activity class declared in your
// AndroidManifest.xml is wrong or has not provided the correct FlutterEngine."
class MainActivity: AudioServiceFragmentActivity() {
}
