<?php
// Configuración estática del sitio que la app Flutter necesita y que en el
// sitio web vive repartida en assets/js/core/radio.js y
// assets/js/components/chatbot.js (STREAM_URL, dolivBotLinks, número de
// WhatsApp). Centralizarla aquí evita tener que duplicarla a mano en Dart.
require_once __DIR__ . '/_bootstrap.php';

api_ok([
    'stream_url' => 'https://stream.zeno.fm/vrfurwfubkhtv',
    'station_name' => 'Radio Doliv',
    'whatsapp' => 'https://wa.me/5217131205259',
    'social' => [
        'instagram' => 'https://www.instagram.com/radio_doliv/',
        'facebook' => 'https://www.facebook.com/people/RADIO-DOLIV/61574197135745/',
        'tiktok' => 'https://www.tiktok.com/@radio_doliv',
        'youtube' => 'https://youtube.com/@r_doliv?si=fZA7DtkJsxY3rGpl',
    ],
    'chat_endpoint' => api_absolute_url('inc/api/dolibot-chat.php'),
]);
