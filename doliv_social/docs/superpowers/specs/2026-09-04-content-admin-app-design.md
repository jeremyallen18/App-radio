# App de administración de contenido — Radio Doliv

## Contexto

`RADIODOLIV_PAGINA` (sitio público, PHP plano) lee su contenido de 7
secciones desde `hive_db` vía `inc/data/*.php`. `App-radio/hive-backend`
(mismo repo de backend que usa la app interna de RRHH) ya expone un CRUD
completo para esas 7 secciones en `site_content.php`, protegido para el rol
`director`. No existe ningún panel de administración — el director edita el
sitio a mano en la base de datos o no lo edita.

Este proyecto (`doliv_social`, Flutter, actualmente vacío) será una app de
administración simple y para principiantes que consuma esa API existente.
No se toca `RADIODOLIV_PAGINA` ni `hive-backend` — solo se consume.

Backend local: `http://localhost/hive-backend` (XAMPP). Sitio público local:
`http://localhost/RADIODOLIV_PAGINA`. Ambos comparten `hive_db` y ambos
directorios son hermanos bajo `htdocs/radio-doliv/`.

## Alcance

Administrar (listar, crear, editar, eliminar) las 7 secciones:
Servicios, Programas, Podcast, Anuncios, Eventos, Equipo, Sección azul
(patrocinadores).

Fuera de alcance: cualquier cambio a `hive-backend` o `RADIODOLIV_PAGINA`;
gestión de usuarios/roles; funciones de RRHH del backend (tareas, asistencia,
etc.) — no se tocan.

## Decisiones (confirmadas con el usuario)

- **Auth**: login real con usuario `director` existente (reutiliza
  `POST /user/login` + `GET /user/me`), no la API key estática.
- **Imágenes**: se pueden subir desde galería (`image_picker`) en cada
  formulario que las soporte.
- **Borrado**: incluido, con diálogo de confirmación antes de llamar al
  endpoint `delete`.

## Arquitectura

Flutter simple: `StatefulWidget`/`setState` (sin Provider/Riverpod/Bloc),
`http` para las llamadas, `shared_preferences` para persistir el token,
`image_picker` para elegir fotos. Sin generación de código, sin backend
propio.

### Estructura de carpetas

```
lib/
  core/
    api_config.dart      # baseUrl (configurable por plataforma: 10.0.2.2 en emulador Android, localhost en el resto)
    api_client.dart       # Authorization: Bearer <token>, get()/postMultipart(), decodifica errores del backend
    session.dart          # guardar/leer/borrar token vía SharedPreferences
  models/
    anuncio.dart
    evento.dart
    servicio.dart
    integrante.dart
    programa.dart
    patrocinador.dart      # incluye lista de SponsorSocial
    podcast.dart           # incluye lista de PodcastEpisode
  screens/
    login_screen.dart
    home_screen.dart       # menú con las 7 secciones
    anuncios/list_screen.dart, form_screen.dart
    eventos/list_screen.dart, form_screen.dart
    servicios/list_screen.dart, form_screen.dart
    equipo/list_screen.dart, form_screen.dart
    programas/list_screen.dart, form_screen.dart
    patrocinadores/list_screen.dart, form_screen.dart
    podcasts/list_screen.dart, form_screen.dart
  widgets/
    content_list_tile.dart   # imagen + título + subtítulo + editar/borrar, reusado en las 7 listas
    labeled_text_field.dart  # TextFormField con label, reusado en los 7 formularios
    image_picker_field.dart  # preview + botón "cambiar imagen"
main.dart
```

Cada sección tiene su propia pantalla de lista y de formulario — no un
motor CRUD genérico — porque los campos varían mucho de sección a sección
(programas tiene ~16 campos; patrocinadores y podcasts tienen sublistas
editables de redes/episodios que no aplican a las demás). Repetir el
patrón simple 7 veces es más legible para una app "principiante" que un
sistema configurable genérico. Solo se comparten los widgets pequeños de
UI listados arriba.

### Flujo de autenticación

1. `POST /user/login` con header `X-Client-Features: login-object` y body
   `{email, password}` → responde `{token, emailVerified}`.
2. `GET /user/me` con `Authorization: Bearer <token>` → si `role !=
   'director'`, mostrar error "Esta cuenta no tiene permisos de
   administrador" y no guardar sesión.
3. Si es director: guardar token en `SharedPreferences`, navegar a
   `HomeScreen`.
4. Al abrir la app, si ya hay token guardado, saltar login e ir directo a
   `HomeScreen` (validar con `GET /user/me`; si falla con 401, borrar token
   y mostrar login).

### Flujo CRUD (igual para las 7 secciones)

1. **Lista**: `GET /site/<recurso>` con Bearer token → `ListView` con
   pull-to-refresh, cada fila usa `content_list_tile.dart`. FAB para crear.
2. **Crear/editar**: formulario prellenado en modo edición → al guardar,
   `POST /site/<recurso>` (crear) o `POST /site/<recurso>/<id>` (editar)
   como `multipart/form-data` con los campos de texto + archivo de imagen
   opcional (solo si el usuario eligió una nueva). Al éxito, `pop` y
   refrescar la lista.
3. **Borrar**: `AlertDialog` de confirmación → `POST
   /site/<recurso>/<id>/delete` → refrescar lista.
4. **Imágenes**: el backend devuelve rutas relativas a `RADIODOLIV_PAGINA`
   (ej. `assets/img/anuncios/foo.jpg`). Se muestran con `Image.network`
   armando la URL como `http://<host-del-sitio>/RADIODOLIV_PAGINA/<ruta>`.
   Host del sitio configurable junto al de la API en `api_config.dart`
   (mismo host, distinto path que el backend).

### Campos por sección (de `site_content.php`, para los formularios)

- **Anuncios** (`/site/anuncios`, tabla `anuncios`): `titulo`* , `descripcion`,
  `imagen` (file), `link_web`, `link_facebook`, `link_whatsapp`,
  `fecha_publicacion` (date).
- **Eventos** (`/site/eventos`, tabla `radio_events`): `title`*, `artist`,
  `location`, `weekday`, `day`, `month`, `year`, `event_date` (date),
  `time_label`, `description`, `image` (file), `sort_order` (int).
- **Servicios** (`/site/servicios`, tabla `radio_services`): `title`*,
  `image` (file), `description`, `whatsapp_url`, `category`, `icon`,
  `sort_order` (int).
- **Equipo** (`/site/equipo`, tabla `radio_team`): `name`*, `role`,
  `category`, `accent`, `image` (file), `short_desc`, `bio` (textarea,
  una idea por línea), `path` (textarea), `interests` (textarea),
  `sort_order` (int).
- **Programas** (`/site/programas`, tabla `radio_programs`): `title`*,
  `modal_title`, `host`, `schedule`, `slot_start`/`slot_end` (int u
  vacío), `weekdays` (CSV de días 1-7), `badge_icon`, `badge_time`,
  `badge_label`, `accent`, `icon`, `image` (file), `categories`,
  `card_desc`, `index_desc`, `summary`, `sort_order` (int).
- **Patrocinadores / Sección azul** (`/site/patrocinadores`, tablas
  `sponsors`+`sponsor_socials`): `name`*, `category`, `category_label`,
  `icon`, `image` (file), `subtitle`, `summary`, `description`
  (textarea), `map`, `sort_order` (int), `socials_json` = lista editable
  en el formulario de `{label, icon, url}` (agregar/quitar filas,
  serializar a JSON antes de enviar).
- **Podcasts** (`/site/podcasts`, tablas `radio_podcasts`+
  `radio_podcast_episodes`): `title`*, `filter_icon`, `cover` (file),
  `sort_order` (int), `episodes_json` = lista editable de
  `{title, description, audio_url, category_label}`.

(`*` = campo requerido por el backend, error 400 si viene vacío.)

### Manejo de errores

- 401 (token inválido/expirado en cualquier llamada): borrar sesión,
  volver a `LoginScreen`.
- 403 / rol no director: mensaje y no dejar pasar.
- 400/404/500: `SnackBar` con el campo `error` del JSON de respuesta del
  backend.
- Sin conexión / timeout: `SnackBar` genérico "No se pudo conectar".

### Testing

Alcance mínimo acorde a "app sencilla": un widget test de `LoginScreen`
(se renderiza, valida campos vacíos) y uno de una lista (ej. anuncios)
con un `http.Client` fake. No se busca cobertura exhaustiva de las 7
secciones dado que comparten el mismo patrón ya probado en una de ellas.

### Dependencias nuevas (`pubspec.yaml`)

`http`, `shared_preferences`, `image_picker`.

## Fuera de alcance / no construido en esta fase

- Reordenar (`sort_order`) por drag-and-drop — se edita como número en el
  formulario.
- Previsualización del sitio público dentro de la app.
- Notificaciones o sincronización en tiempo real.
