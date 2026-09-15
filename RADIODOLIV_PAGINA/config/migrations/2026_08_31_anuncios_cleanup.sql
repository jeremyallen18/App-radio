-- Migración de datos: limpieza de la cartelera de anuncios.
--
-- La tabla `anuncios` (hive_db) arrastraba varias filas de prueba de las
-- primeras cargas del sitio ("Prueba", "Anuncio 2", "Anuncio 3", el TEST de
-- recorte tipografico) y el "Festival Dolifest 2026", que ya no va en la
-- cartelera. Se dejan solo los tres anuncios reales en uso (31 Minutos,
-- Lufesca y El Reporterito) y se agrega el de la Carrera del Tecnologico de
-- Santiago Tilapa, para alumnos y maestros, sin enlace todavia.
--
-- Ejecutar una sola vez con:
--   php config/migrations/migrate_anuncios_cleanup.php

-- 1) Alta del anuncio de la carrera. Idempotente: no se duplica si ya existe.
INSERT INTO anuncios (titulo, descripcion, imagen_url, link_web, link_facebook, link_whatsapp, fecha_publicacion)
SELECT
    'Carrera del Tecnológico de Santiago Tilapa',
    'El Tecnológico de Santiago Tilapa invita a alumnos y maestros a su carrera atlética el viernes 4 de septiembre. Distancias de 3K y 5K, con medalla conmemorativa, premios a los ganadores e hidratación y apoyo en ruta. Pronto se abren las inscripciones.',
    'assets/img/anuncios/carrera-tecnologico-santiago-tilapa.jpg',
    NULL, NULL, NULL,
    CURRENT_DATE()
WHERE NOT EXISTS (
    SELECT 1 FROM anuncios WHERE titulo = 'Carrera del Tecnológico de Santiago Tilapa'
);

-- 1b) Si el anuncio ya existía (p. ej. de una corrida previa con la imagen
--     provisional en SVG), se actualiza a la imagen optimizada y al texto
--     con la fecha confirmada.
UPDATE anuncios
SET descripcion = 'El Tecnológico de Santiago Tilapa invita a alumnos y maestros a su carrera atlética el viernes 4 de septiembre. Distancias de 3K y 5K, con medalla conmemorativa, premios a los ganadores e hidratación y apoyo en ruta. Pronto se abren las inscripciones.',
    imagen_url  = 'assets/img/anuncios/carrera-tecnologico-santiago-tilapa.jpg'
WHERE titulo = 'Carrera del Tecnológico de Santiago Tilapa';

-- 2) Baja de todo lo que no sean los tres anuncios en uso ni el recién creado.
DELETE FROM anuncios
WHERE titulo NOT IN (
    '31 Minutos llega a Tlalnepantla',
    'Lufesca: nueva temporada',
    'El Reporterito: convocatoria abierta',
    'Carrera del Tecnológico de Santiago Tilapa'
);
