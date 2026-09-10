<?php
// Agrega todas las fuentes de datos (inc/data/*.php) en el formato plano que
// consume assets/js/components/search.js. Reemplaza el antiguo
// assets/js/data/search-items.js (mantenido a mano, desincronizado del
// contenido real) por una única fuente derivada de los mismos datos que
// renderizan las páginas.
require_once __DIR__ . '/programs.php';
require_once __DIR__ . '/podcasts.php';
require_once __DIR__ . '/events.php';
require_once __DIR__ . '/team.php';
require_once __DIR__ . '/sponsors.php';
require_once __DIR__ . '/services.php';
require_once __DIR__ . '/announcements.php';

function build_search_index(): array {
    $items = [];

    // Páginas principales (equivalente a los enlaces del navbar).
    $items[] = ['group' => 'Páginas', 'icon' => 'home', 'title' => 'Inicio', 'subtitle' => 'Página principal', 'description' => 'Radio en vivo, programas destacados y comunidad Radio Doliv.', 'url' => 'index.php', 'keywords' => 'home principal radio en vivo inicio doliv'];
    $items[] = ['group' => 'Páginas', 'icon' => 'building-2', 'title' => 'Conócenos', 'subtitle' => 'Nuestra esencia', 'description' => 'Misión, visión, valores e historia de Radio Doliv.', 'url' => 'pages/conocenos.php', 'keywords' => 'quienes somos mision vision valores historia'];
    $items[] = ['group' => 'Páginas', 'icon' => 'briefcase', 'title' => 'Servicios', 'subtitle' => 'Soluciones para marcas', 'description' => 'Publicidad, contenido, transmisiones, redes, podcast y activaciones.', 'url' => 'pages/servicios.php', 'keywords' => 'servicios cotizar whatsapp publicidad marcas'];
    $items[] = ['group' => 'Páginas', 'icon' => 'radio', 'title' => 'Programas', 'subtitle' => 'Parrilla Radio Doliv', 'description' => 'Horarios, categorías y detalles de cada programa al aire.', 'url' => 'pages/programas.php', 'keywords' => 'programas horarios parrilla radio'];
    $items[] = ['group' => 'Páginas', 'icon' => 'mic-2', 'title' => 'Podcast', 'subtitle' => 'Catálogo de podcasts', 'description' => 'Episodios, audios y conversaciones disponibles.', 'url' => 'pages/podcast.php', 'keywords' => 'podcasts episodios audio escuchar'];
    $items[] = ['group' => 'Páginas', 'icon' => 'megaphone', 'title' => 'Anuncios', 'subtitle' => 'Información y promociones', 'description' => 'Anuncios activos, promociones y enlaces de contacto.', 'url' => 'pages/anuncios.php', 'keywords' => 'anuncios promociones informacion comunidad'];
    $items[] = ['group' => 'Páginas', 'icon' => 'calendar-days', 'title' => 'Eventos', 'subtitle' => 'Experiencias en vivo', 'description' => 'Eventos, shows y actividades especiales de Radio Doliv.', 'url' => 'pages/eventos.php', 'keywords' => 'eventos shows vivo'];
    $items[] = ['group' => 'Páginas', 'icon' => 'users', 'title' => 'Equipo', 'subtitle' => 'Nuestro equipo', 'description' => 'Conoce a las personas detrás de Radio Doliv.', 'url' => 'pages/equipo.php', 'keywords' => 'equipo locutores conductores personas'];
    $items[] = ['group' => 'Páginas', 'icon' => 'info', 'title' => 'Sección azul', 'subtitle' => 'Directorio de aliados', 'description' => 'Patrocinadores, instituciones, negocios, redes sociales y ubicaciones.', 'url' => 'pages/seccionazul.php', 'keywords' => 'seccion azul especial patrocinadores aliados directorio'];

    // Anuncios reales desde la BD compartida (en vez de entradas estáticas desincronizadas).
    $announcements = get_announcements();
    foreach ($announcements['items'] as $item) {
        $items[] = [
            'group' => 'Anuncios', 'icon' => 'megaphone',
            'title' => $item['titulo'] ?? 'Anuncio', 'subtitle' => 'Anuncio Radio Doliv',
            'description' => $item['descripcion'] ?? '', 'url' => 'pages/anuncios.php',
            'keywords' => strtolower((string) ($item['titulo'] ?? '')),
        ];
    }

    foreach (get_sponsors() as $sponsor) {
        $items[] = [
            'group' => 'Aliados', 'icon' => $sponsor['icon'], 'title' => $sponsor['name'],
            'subtitle' => $sponsor['category_label'], 'description' => $sponsor['summary'],
            'url' => 'pages/seccionazul.php', 'keywords' => strtolower($sponsor['name'] . ' ' . $sponsor['category_label']),
        ];
    }

    foreach (get_services() as $service) {
        $items[] = [
            'group' => 'Servicios', 'icon' => 'briefcase', 'title' => $service['title'],
            'subtitle' => 'Servicios Radio Doliv', 'description' => $service['description'],
            'url' => 'pages/servicios.php', 'keywords' => strtolower($service['title'] . ' cotizar cotizacion presupuesto ' . $service['category']),
        ];
    }

    foreach (get_programs() as $program) {
        $items[] = [
            'group' => 'Programas', 'icon' => 'radio', 'title' => $program['title'],
            'subtitle' => $program['schedule'], 'description' => $program['index_desc'],
            'url' => 'pages/programas.php', 'keywords' => strtolower($program['title'] . ' ' . $program['categories']),
        ];
    }

    foreach (get_podcasts() as $podcast) {
        $items[] = [
            'group' => 'Podcasts', 'icon' => $podcast['filter_icon'], 'title' => $podcast['title'],
            'subtitle' => count($podcast['episodes']) ? 'Episodios disponibles' : 'Próximamente',
            'description' => count($podcast['episodes']) ? ('Episodios: ' . implode(', ', array_column($podcast['episodes'], 'title'))) : 'Podcast preparado para próximos episodios.',
            'url' => 'pages/podcast.php', 'keywords' => strtolower($podcast['title']),
        ];
        foreach ($podcast['episodes'] as $episode) {
            $items[] = [
                'group' => 'Podcast', 'icon' => 'play-circle', 'title' => $episode['title'],
                'subtitle' => $podcast['title'], 'description' => $episode['description'],
                'url' => 'pages/podcast.php', 'keywords' => strtolower($episode['title'] . ' ' . $podcast['title']),
            ];
        }
    }

    foreach (get_active_events() as $event) {
        $entry = [
            'group' => 'Eventos', 'icon' => 'music', 'title' => $event['title'],
            'subtitle' => $event['time'], 'description' => $event['description'],
            'url' => 'pages/eventos.php', 'keywords' => strtolower($event['title'] . ' ' . $event['location']),
        ];
        if (!empty($event['event_date'])) {
            $entry['eventDate'] = $event['event_date'];
        }
        $items[] = $entry;
    }

    foreach (get_team() as $member) {
        $items[] = [
            'group' => 'Equipo', 'icon' => 'user', 'title' => $member['name'],
            'subtitle' => $member['role'], 'description' => $member['short'],
            'url' => 'pages/equipo.php', 'keywords' => strtolower($member['name'] . ' ' . $member['role'] . ' locutor locutora locutores conductora conductor equipo'),
        ];
    }

    return $items;
}
