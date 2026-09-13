# API de contenido del sitio público (`/site/*`)

Gestiona el contenido de RADIODOLIV_PAGINA (anuncios, eventos, servicios,
equipo, programas, patrocinadores, podcasts) desde `hive-backend`. Todas las
respuestas incluyen `"version": "1"` junto al payload existente.

## Autenticación

Dos formas, ambas siguen funcionando siempre (ver `site_actor_context()` en
`hive-backend/site_audit.php`):

1. **Sesión de director** (app Flutter): `Authorization: Bearer <token>` de
   un usuario con `role = 'director'` (`require_auth()` + `require_role(['director'])`).
2. **Llave de API** (integración interna, p. ej. beta_web): cabecera
   `X-Api-Key: <SITE_CONTENT_KEY>`. En producción (`APP_ENV=production`) la
   llave debe tener 32+ caracteres o el servidor responde 500 en cada
   petición. Hoy la llave tiene acceso total (`site:read`, `site:write`,
   `site:delete`, ver `SITE_CONTENT_SCOPES`); el campo `scopes` del contexto
   interno deja preparada la estructura para llaves más restringidas en el
   futuro sin cambiar el contrato HTTP.

Cada endpoint exige un scope concreto internamente (`site:read` para listar,
`site:write` para crear/actualizar, `site:delete` para borrar); con la sesión
de director y con la llave de hoy los tres siempre están disponibles.

Errores comunes: `401 {"error":"Missing Authorization header"}`,
`401 {"error":"Invalid or expired token"}`,
`403 {"error":"No tienes permiso para realizar esta acción"}`,
`403 {"error":"La credencial usada no tiene el alcance requerido: site:write"}`.

Todas las respuestas — listas, ítems individuales, y `delete` — incluyen
`"version": "1"` (ver `site_response_item()` / `site_response_list()` en
`site_audit.php`), para que los clientes puedan detectar cambios futuros de
contrato sin adivinar por la forma del payload.

---

## Anuncios (`anuncios`)

### `GET /site/anuncios` — listar

Requiere: sesión de director o `X-Api-Key`.

Respuesta 200:
```json
{
  "version": "1",
  "items": [
    {
      "id": 1, "titulo": "...", "descripcion": "...", "imagen_url": "assets/img/anuncios/....jpg",
      "link_web": "https://...", "link_facebook": "https://...", "link_whatsapp": "https://...",
      "fecha_publicacion": "2026-09-01"
    }
  ]
}
```

### `POST /site/anuncios` — crear

Multipart form fields:

- `titulo` (requerido, texto)
- `descripcion` (opcional, texto)
- `imagen` (opcional, archivo — jpg/jpeg/png/gif/webp, máx. 5 MB, debe ser una imagen real)
- `link_web`, `link_facebook`, `link_whatsapp` (opcionales, URL — si se mandan deben empezar con `http://` o `https://`, si no la petición se rechaza; vacío se guarda como `''`)
- `fecha_publicacion` (opcional, fecha `AAAA-MM-DD` válida; vacío se guarda como `NULL`)

Ejemplo:

```bash
curl -X POST http://localhost/hive-backend/site/anuncios \
  -H "Authorization: Bearer $TOKEN" \
  -F "titulo=Feria de la radio" \
  -F "fecha_publicacion=2026-09-20" \
  -F "link_web=https://radiodoliv.com/feria" \
  -F "imagen=@feria.jpg"
```

Respuesta 201: mismo shape que un elemento de `items` arriba, envuelto en `{"version": "1", "item": {...}}`.

Errores: `400 {"error":"titulo es requerido"}`, `400 {"error":"La imagen supera el tamaño máximo permitido (5 MB)"}`, `400 {"error":"Solo se permiten imágenes jpg, jpeg, png, gif o webp"}`, `400 {"error":"link_web no es una URL válida (debe empezar con http:// o https://)"}`, `400 {"error":"fecha_publicacion debe ser una fecha válida (AAAA-MM-DD)"}`.

### `POST /site/anuncios/{id}` — actualizar

Mismos campos que crear. `imagen` es opcional: si no se manda, conserva la imagen actual; si se manda una nueva, la anterior se borra del servidor tras guardar con éxito.

Errores adicionales: `404 {"error":"Anuncio no encontrado"}`.

### `POST /site/anuncios/{id}/delete` — eliminar

Respuesta 200: `{"version": "1", "ok": true}`. Si el id no existe: `404 {"error": "Resource not found"}`.

---

## Eventos (`radio_events`)

### `GET /site/eventos` — listar

Requiere: sesión de director o `X-Api-Key`. Orden: `sort_order ASC, id ASC`.

Respuesta 200:
```json
{
  "version": "1",
  "items": [
    {
      "id": 1, "slug": "banda-x", "title": "Banda X", "artist": "...", "location": "...",
      "image": "assets/img/eventos/....jpg", "weekday": "...", "day": "...", "month": "...",
      "year": "...", "event_date": "2026-10-05", "time_label": "8:00 pm", "description": "...",
      "sort_order": 0
    }
  ]
}
```

### `POST /site/eventos` — crear

Multipart form fields:

- `title` (requerido, texto — también genera el `slug` único vía `site_unique_slug()`)
- `artist`, `location`, `weekday`, `day`, `month`, `year`, `time_label`, `description` (opcionales, texto)
- `event_date` (opcional, fecha `AAAA-MM-DD` válida; vacío se guarda como `NULL`)
- `sort_order` (opcional, entero; vacío o ausente = `0`)
- `image` (opcional, archivo — jpg/jpeg/png/gif/webp, máx. 5 MB, debe ser una imagen real)

Ejemplo:

```bash
curl -X POST http://localhost/hive-backend/site/eventos \
  -H "Authorization: Bearer $TOKEN" \
  -F "title=Banda X" -F "event_date=2026-10-05" -F "time_label=8:00 pm" \
  -F "image=@banda-x.jpg"
```

Respuesta 201: mismo shape que un elemento de `items` arriba, envuelto en `{"version": "1", "item": {...}}`.

Errores: `400 {"error":"title es requerido"}`, `400 {"error":"event_date debe ser una fecha válida (AAAA-MM-DD)"}`, `400 {"error":"sort_order debe ser un número entero"}`, `400 {"error":"La imagen supera el tamaño máximo permitido (5 MB)"}`.

### `POST /site/eventos/{id}` — actualizar

Mismos campos que crear (el `slug` no se regenera al actualizar). `image` es opcional: si no se manda, conserva la imagen actual; si se manda una nueva, la anterior se borra del servidor tras guardar con éxito.

Errores adicionales: `404 {"error":"Evento no encontrado"}`.

### `POST /site/eventos/{id}/delete` — eliminar

Respuesta 200: `{"version": "1", "ok": true}`. Si el id no existe: `404 {"error": "Resource not found"}`.

---

## Servicios (`radio_services`)

### `GET /site/servicios` — listar

Requiere: sesión de director o `X-Api-Key`. Orden: `sort_order ASC, id ASC`.

Respuesta 200:
```json
{
  "version": "1",
  "items": [
    {
      "id": 1, "title": "Publicidad", "image": "assets/img/servicios/....jpg", "description": "...",
      "whatsapp_url": "https://wa.me/...", "category": "anunciantes", "icon": "megaphone",
      "sort_order": 0
    }
  ]
}
```

### `POST /site/servicios` — crear

Multipart form fields:

- `title` (requerido, texto)
- `category` (**requerido**, texto libre — agrupa servicios en `get_services_by_category()` del sitio público; no tiene un catálogo fijo de valores, pero debe venir siempre para que el agrupamiento tenga sentido. Ya no existen filas legado con `category` vacío, por lo que quedó requerido)
- `description`, `icon` (opcionales, texto)
- `whatsapp_url` (opcional, URL — si se manda debe empezar con `http://` o `https://`)
- `sort_order` (opcional, entero; vacío o ausente = `0`)
- `image` (opcional, archivo — jpg/jpeg/png/gif/webp, máx. 5 MB, debe ser una imagen real)

Ejemplo:

```bash
curl -X POST http://localhost/hive-backend/site/servicios \
  -H "Authorization: Bearer $TOKEN" \
  -F "title=Publicidad" -F "category=anunciantes" \
  -F "whatsapp_url=https://wa.me/50212345678" \
  -F "image=@publicidad.jpg"
```

Respuesta 201: mismo shape que un elemento de `items` arriba, envuelto en `{"version": "1", "item": {...}}`.

Errores: `400 {"error":"title es requerido"}`, `400 {"error":"category es requerido"}`, `400 {"error":"whatsapp_url no es una URL válida (debe empezar con http:// o https://)"}`, `400 {"error":"sort_order debe ser un número entero"}`.

### `POST /site/servicios/{id}` — actualizar

Mismos campos que crear (incluido `category`, requerido también aquí). `image` es opcional: si no se manda, conserva la imagen actual; si se manda una nueva, la anterior se borra del servidor tras guardar con éxito.

Errores adicionales: `404 {"error":"Servicio no encontrado"}`.

### `POST /site/servicios/{id}/delete` — eliminar

Respuesta 200: `{"version": "1", "ok": true}`. Si el id no existe: `404 {"error": "Resource not found"}`.

---

## Equipo (`radio_team`)

### `GET /site/equipo` — listar

Requiere: sesión de director o `X-Api-Key`.

Respuesta 200:
```json
{
  "version": "1",
  "items": [
    {
      "id": 1, "slug": "fernanda-r", "name": "Fernanda R.", "role": "Conductora",
      "category": "locutores", "accent": "#ff6b35", "image": "assets/img/locutores/fernanda-r-a1b2c3d4.jpg",
      "short_desc": "...", "bio": "...", "path": "...", "interests": "...", "sort_order": 0,
      "socials": [{"label": "Instagram", "icon": "instagram", "url": "https://instagram.com/x"}],
      "program_ids": [3, 7]
    }
  ]
}
```

### `POST /site/equipo` — crear

Multipart form fields:

- `name` (requerido, texto)
- `category` (requerido, uno de: `locutores`, `reporteros` — único recurso con un enum fijo de categoría)
- `role`, `accent`, `short_desc` (opcionales, texto)
- `bio`, `path`, `interests` (opcionales, texto multilínea — una idea por línea; `bio` usa líneas en blanco para separar párrafos)
- `image` (opcional, archivo — jpg/jpeg/png/gif/webp, máx. 5 MB, debe ser una imagen real)
- `socials_json` (opcional, JSON: `[{"label": "Instagram", "icon": "instagram", "url": "https://..."}]` — cada `url` debe ser http(s) válida o la petición entera se rechaza)
- `program_ids` (opcional, ids de `radio_programs` separados por coma — vincula este integrante como conductor de esos programas; cualquier id inexistente rechaza la petición completa)

Ejemplo:

```bash
curl -X POST http://localhost/hive-backend/site/equipo \
  -H "Authorization: Bearer $TOKEN" \
  -F "name=Fernanda R." -F "category=locutores" \
  -F "socials_json=[{\"label\":\"Instagram\",\"icon\":\"instagram\",\"url\":\"https://instagram.com/x\"}]" \
  -F "program_ids=3,7" \
  -F "image=@fernanda.jpg"
```

Respuesta 201: mismo shape que un elemento de `items` arriba, envuelto en `{"version": "1", "item": {...}}`.

Errores: `400 {"error":"name es requerido"}`, `400 {"error":"category debe ser \"locutores\" o \"reporteros\"."}`, `400 {"error":"La imagen supera el tamaño máximo permitido (5 MB)"}`, `400 {"error":"socials_json[0].url no es una URL válida (debe empezar con http:// o https://)"}`, `400 {"error":"program_ids contiene un id que ya no existe"}`.

### `POST /site/equipo/{id}` — actualizar

Mismos campos que crear. `image` es opcional: si no se manda, conserva la imagen actual; si se manda una nueva, la anterior se borra del servidor tras guardar con éxito. `sort_order` no se puede editar aquí (solo cambia al crear un integrante nuevo, que reordena a todos los demás).

Errores adicionales: `404 {"error":"Integrante no encontrado"}`.

### `POST /site/equipo/{id}/delete` — eliminar

Borra el integrante y sus redes sociales (`ON DELETE CASCADE`) y sus vínculos de programa.

Respuesta 200: `{"version": "1", "ok": true}`. Si el id no existe: `404 {"error": "Resource not found"}`.

---

## Programas (`radio_programs`)

### `GET /site/programas` — listar

Requiere: sesión de director o `X-Api-Key`. Incluye `host_team_ids` (locutores vinculados vía `radio_program_hosts`).

Respuesta 200:
```json
{
  "version": "1",
  "items": [
    {
      "id": 1, "slug": "manana-activa", "title": "Mañana Activa", "modal_title": "...",
      "host": "Fernanda y Amanda", "schedule": "Lun, Mar, Mié | 06:00 - 09:00",
      "slot_start": 6, "slot_end": 9, "weekdays": "1,2,3", "badge_icon": "...",
      "badge_time": "06:00 - 09:00", "badge_label": "...", "accent": "#ff6b35", "icon": "...",
      "image": "assets/img/programas/....jpg", "categories": "...", "card_desc": "...",
      "index_desc": "...", "summary": "...", "sort_order": 0, "host_team_ids": [3, 7]
    }
  ]
}
```

### `POST /site/programas` — crear

Multipart form fields:

- `title` (requerido, texto — también genera el `slug` único)
- `modal_title`, `badge_icon`, `badge_label`, `accent`, `icon`, `categories`, `card_desc`, `index_desc`, `summary` (opcionales, texto)
- `slot_start`, `slot_end` (opcionales, hora entera 0-23 — deben venir ambas o ninguna, y no pueden ser iguales; ver errores abajo)
- `weekdays` (opcional, ids de día 1-7 separados por coma, 1 = lunes, 7 = domingo; cualquier valor fuera de rango rechaza la petición)
- `host` (opcional, texto libre — solo se usa si NO se manda `host_team_ids`; si se manda `host_team_ids`, `host` se recalcula siempre a partir de los nombres reales)
- `host_team_ids` (opcional, ids de `radio_team` separados por coma — vincula locutores reales como conductores; cualquier id inexistente rechaza la petición completa)
- `schedule`, `badge_time` (opcionales, texto — se recalculan automáticamente y sobrescriben lo enviado si `slot_start`/`slot_end` vienen ambos)
- `sort_order` (opcional, entero; vacío o ausente = `0` — a diferencia de otros recursos, este campo usa `(int) ($_POST['sort_order'] ?? 0)` directamente, no `site_valid_int()`, así que un valor no numérico se castea silenciosamente a `0` en vez de dar error 400)
- `image` (opcional, archivo — jpg/jpeg/png/gif/webp, máx. 5 MB, debe ser una imagen real)

Ejemplo:

```bash
curl -X POST http://localhost/hive-backend/site/programas \
  -H "Authorization: Bearer $TOKEN" \
  -F "title=Mañana Activa" \
  -F "slot_start=6" -F "slot_end=9" -F "weekdays=1,2,3" \
  -F "host_team_ids=3,7" \
  -F "image=@manana-activa.jpg"
```

Respuesta 201: mismo shape que un elemento de `items` arriba, envuelto en `{"version": "1", "item": {...}}`.

Errores: `400 {"error":"title es requerido"}`, `400 {"error":"slot_start debe estar entre 0 y 23"}`, `400 {"error":"Indica la hora de inicio y la hora final, o deja ambas vacías."}`, `400 {"error":"La hora de inicio y la hora final no pueden ser iguales."}`, `400 {"error":"Los días de transmisión deben estar entre 1 (lunes) y 7 (domingo)."}`, `400 {"error":"host_team_ids contiene un id que ya no existe"}`.

### `POST /site/programas/{id}` — actualizar

Mismos campos que crear. `host_team_ids` reemplaza por completo la lista de locutores vinculados (borra y re-inserta); si no se manda o llega vacío, el programa queda sin locutores vinculados y `host` vuelve a ser texto libre. `image` es opcional: si no se manda, conserva la imagen actual; si se manda una nueva, la anterior se borra del servidor tras guardar con éxito.

Errores adicionales: `404 {"error":"Programa no encontrado"}`.

### `POST /site/programas/{id}/delete` — eliminar

Respuesta 200: `{"version": "1", "ok": true}`. Si el id no existe: `404 {"error": "Resource not found"}`.

> Nota: existe además `GET /radio/programs`, un endpoint de solo lectura para cualquier usuario autenticado (no solo director) que la app usa para mostrar la parrilla de programación; no forma parte de este contrato de administración y su respuesta NO incluye `version`.

---

## Patrocinadores (`sponsors` + `sponsor_socials`)

### `GET /site/patrocinadores` — listar

Requiere: sesión de director o `X-Api-Key`. Orden: `sort_order ASC, id ASC`.

Respuesta 200:
```json
{
  "version": "1",
  "items": [
    {
      "id": 1, "name": "Empresa X", "category": "aliados", "category_label": "Aliados",
      "icon": "...", "image": "assets/img/patrocinadores/....jpg", "subtitle": "...",
      "summary": "...", "description": "...", "map": "https://maps.google.com/...",
      "sort_order": 0,
      "socials": [{"label": "Facebook", "icon": "facebook", "url": "https://facebook.com/x"}]
    }
  ]
}
```

### `POST /site/patrocinadores` — crear

Multipart form fields:

- `name` (requerido, texto)
- `category`, `category_label` (**requeridos**, texto — ya no existen filas legado con estos campos vacíos, por lo que quedaron requeridos)
- `map` (requerido implícitamente por formato: si se manda debe ser una URL http(s) real, o la petición se rechaza; el valor se inyecta sin escapar como `src=` de un `<iframe>` en `seccionazul.js` del sitio público, así que nunca puede ser texto libre)
- `icon`, `subtitle`, `summary` (opcionales, texto)
- `description` (opcional, texto multilínea)
- `sort_order` (opcional, entero; vacío o ausente = `0`)
- `image` (opcional, archivo — jpg/jpeg/png/gif/webp, máx. 5 MB, debe ser una imagen real)
- `socials_json` (opcional, JSON: `[{"label": "Facebook", "icon": "facebook", "url": "https://..."}]` — cada `url` debe ser http(s) válida o la petición entera se rechaza)

Ejemplo:

```bash
curl -X POST http://localhost/hive-backend/site/patrocinadores \
  -H "Authorization: Bearer $TOKEN" \
  -F "name=Empresa X" -F "category=aliados" -F "category_label=Aliados" \
  -F "map=https://maps.google.com/?q=Empresa+X" \
  -F "socials_json=[{\"label\":\"Facebook\",\"icon\":\"facebook\",\"url\":\"https://facebook.com/x\"}]" \
  -F "image=@empresa-x.jpg"
```

Respuesta 201: mismo shape que un elemento de `items` arriba, envuelto en `{"version": "1", "item": {...}}`.

Errores: `400 {"error":"name es requerido"}`, `400 {"error":"category es requerido"}`, `400 {"error":"category_label es requerido"}`, `400 {"error":"map no es una URL válida (debe empezar con http:// o https://)"}`, `400 {"error":"socials_json[0].url no es una URL válida (debe empezar con http:// o https://)"}`.

### `POST /site/patrocinadores/{id}` — actualizar

Mismos campos que crear (incluidos `category`/`category_label`/`map`, requeridos también aquí). `image` es opcional: si no se manda, conserva la imagen actual; si se manda una nueva, la anterior se borra del servidor tras guardar con éxito.

Errores adicionales: `404 {"error":"Patrocinador no encontrado"}`.

### `POST /site/patrocinadores/{id}/delete` — eliminar

Borra el patrocinador y sus redes sociales (`ON DELETE CASCADE`).

Respuesta 200: `{"version": "1", "ok": true}`. Si el id no existe: `404 {"error": "Resource not found"}`.

---

## Podcasts (`radio_podcasts` + `radio_podcast_episodes`)

Este es el único recurso con archivos **por elemento de un arreglo**: cada
episodio de `episodes_json` tiene su propio campo de archivo de audio
`episode_audio_{n}`, donde `n` es el índice (base 0) de ese episodio dentro
del arreglo `episodes_json` enviado en la misma petición. No hay un campo de
archivo único como en las demás secciones.

### `GET /site/podcasts` — listar

Requiere: sesión de director o `X-Api-Key`. Orden: `sort_order ASC, id ASC`.

Respuesta 200:
```json
{
  "version": "1",
  "items": [
    {
      "id": 1, "slug": "voces-del-barrio", "title": "Voces del Barrio", "filter_icon": "...",
      "cover": "assets/img/portadas/....jpg", "sort_order": 0,
      "episodes": [
        {
          "title": "Episodio 1", "description": "...",
          "audio_url": "assets/audio/podcasts/episodio-1-a1b2c3d4.mp3",
          "category_label": "Comunidad"
        }
      ]
    }
  ]
}
```

### `POST /site/podcasts` — crear

Multipart form fields:

- `title` (requerido, texto — también genera el `slug` único)
- `filter_icon` (opcional, texto)
- `sort_order` (opcional, entero; vacío o ausente = `0`)
- `cover` (opcional, archivo — jpg/jpeg/png/gif/webp, máx. 5 MB, debe ser una imagen real)
- `episodes_json` (opcional, JSON: `[{"title": "...", "description": "...", "audio_url": "...", "category_label": "..."}]` — reemplaza por completo la lista de episodios existente en cada `create`/`update`; cada elemento requiere `title` no vacío o la petición entera se rechaza con el índice exacto en el mensaje)
- `episode_audio_0`, `episode_audio_1`, … (opcionales, un campo de archivo por episodio — `episode_audio_{n}` corresponde al episodio en la posición `n` de `episodes_json`; audio mp3/wav/m4a/ogg, máx. 100 MB. Si no se manda el archivo para un episodio, se conserva el `audio_url` que ese elemento ya traía en `episodes_json`; si se manda uno nuevo, el audio anterior de ese episodio se borra del servidor tras un commit exitoso, igual que las imágenes en los demás recursos)

Ejemplo (dos episodios, el primero con audio nuevo, el segundo reutilizando el audio existente):

```bash
curl -X POST http://localhost/hive-backend/site/podcasts \
  -H "Authorization: Bearer $TOKEN" \
  -F "title=Voces del Barrio" \
  -F 'episodes_json=[{"title":"Episodio 1","category_label":"Comunidad"},{"title":"Episodio 2","audio_url":"assets/audio/podcasts/episodio-2-existente.mp3"}]' \
  -F "episode_audio_0=@episodio-1.mp3" \
  -F "cover=@portada.jpg"
```

Respuesta 201: mismo shape que un elemento de `items` arriba, envuelto en `{"version": "1", "item": {...}}`.

Errores: `400 {"error":"title es requerido"}`, `400 {"error":"episodes_json debe ser un arreglo JSON válido"}`, `400 {"error":"episodes_json[0].title es requerido"}`, `400 {"error":"El audio supera el tamaño máximo permitido (100 MB)"}`, `400 {"error":"Solo se permiten archivos de audio mp3, wav, m4a u ogg"}`, `400 {"error":"La imagen supera el tamaño máximo permitido (5 MB)"}`.

### `POST /site/podcasts/{id}` — actualizar

Mismos campos que crear. `cover` es opcional: si no se manda, conserva la portada actual; si se manda una nueva, la anterior se borra del servidor tras guardar con éxito. `episodes_json` sigue reemplazando por completo la lista de episodios en cada actualización (no hay edición parcial de un solo episodio).

Errores adicionales: `404 {"error":"Podcast no encontrado"}`.

### `POST /site/podcasts/{id}/delete` — eliminar

Borra el podcast y sus episodios (`ON DELETE CASCADE`). Nota: los archivos de audio de los episodios en disco NO se borran automáticamente al eliminar el podcast completo (solo se borran al reemplazarse individualmente en un `update`).

Respuesta 200: `{"version": "1", "ok": true}`. Si el id no existe: `404 {"error": "Resource not found"}`.
