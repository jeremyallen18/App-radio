# Radio Doliv — sitio web público (doliv.site)

Es el sitio que ve cualquier visitante: radio en vivo, programas, podcasts, eventos,
equipo, patrocinadores y anuncios. No requiere iniciar sesión.

## 1. Qué es y cómo está hecho

Sitio multipágina en **PHP + HTML + CSS + JavaScript**, sin framework y sin gestor de
paquetes. Casi todas las páginas se generan en el servidor con PHP; el JavaScript solo
se encarga de cosas visuales (reproductor de radio, filtros, buscador, modo claro/oscuro).

Incluye además una pequeña **API de solo lectura** (`api/`) en formato JSON, que es la
que consume la app interna (App-radio) para mostrar el mismo contenido (stream, equipo,
anuncios, etc.) dentro de la app.

## 2. Estructura de carpetas

```
RADIODOLIV_PAGINA/
├── index.php          Página de inicio: radio en vivo, programas, destacados
├── pages/              El resto de páginas (programas, podcast, eventos, equipo, etc.)
├── inc/                Piezas reutilizables: plantillas y acceso a datos (inc/data/*.php)
├── assets/
│   ├── css/            Estilos, organizados por componente y por página
│   ├── js/             Scripts por página (assets/js/pages/) y compartidos (core/)
│   └── img/, audio/    Imágenes y audios que sube el director desde la app
├── api/                Endpoints JSON de solo lectura (uno por sección del sitio)
└── config/             Conexión a la base de datos (`db.php`) y migraciones iniciales
```

## 3. De dónde vienen los datos

El sitio **no tiene su propio panel de administración**: todo el contenido (programas,
eventos, equipo, patrocinadores, podcasts, anuncios) se edita desde la app interna
(App-radio), que lo guarda en la base de datos compartida `hive_db`. Este sitio solo
**lee** esos datos y los muestra.

Por eso ambos proyectos deben apuntar a la **misma base de datos** — ver el
[README general](../README.md) para la instalación de `hive_db`.

> Desde la app, un programa puede vincularse a un integrante real del equipo
> (`radio_programs.host_team_id`) en vez de solo escribir el nombre del locutor a mano.
> `index.php` usa ese vínculo (no el texto libre `host`) para resolver la foto y el link
> a la ficha del locutor en "Suena ahora" y en la parrilla del día — así que un programa
> con `host_team_id` vacío muestra solo el nombre, sin foto ni link, aunque el texto
> coincida por casualidad con el de un integrante del equipo.

## 4. Requisitos

- **Apache + PHP 8+** (XAMPP cumple).
- La base de datos `hive_db` ya creada (ver [README general](../README.md), sección 4).

## 5. Cómo correr el sitio en tu computadora

1. Ubicar esta carpeta bajo el `DocumentRoot` de Apache, por ejemplo:
   `C:\xampp\htdocs\radio-doliv\RADIODOLIV_PAGINA\`.
2. Configurar la conexión a la base de datos:
   ```bash
   copy config\.env.example config\.env
   ```
   Y editar `config/.env` con los datos reales de tu MySQL (usuario, contraseña, nombre
   de la base). Con la configuración estándar de XAMPP (`root` sin contraseña) casi
   nunca hace falta cambiar nada.
3. Prender Apache y MySQL desde el Panel de Control de XAMPP.
4. Abrir `http://localhost/radio-doliv/RADIODOLIV_PAGINA/` en el navegador.

> El sitio usa rutas absolutas desde la raíz del dominio (`/assets/...`, `/pages/...`),
> así que en producción debe servirse desde la raíz del dominio, no desde una subcarpeta.

## 6. La API de solo lectura (`api/`)

Todas las respuestas usan el mismo formato: `{ "success": true/false, ... }`. Un archivo
por recurso, sin necesidad de iniciar sesión:

| Endpoint | Qué devuelve |
|---|---|
| `api/config.php` | Configuración que necesita la app (URL del stream, WhatsApp, etc.) |
| `api/anuncios.php` | Anuncios publicados |
| `api/eventos.php` | Eventos activos |
| `api/programas.php` | Parrilla de programación |
| `api/podcasts.php` | Podcasts y sus episodios |
| `api/equipo.php` | Locutores / equipo |
| `api/servicios.php` | Servicios comerciales |
| `api/seccionazul.php` | Patrocinadores y sus redes sociales |

## 7. Subir a Hostinger

1. Subir **todo el contenido** de esta carpeta a `public_html/` del dominio, **excepto**:
   `.git/`, `config/.env` (se crea directo en el servidor), archivos `.md` y audios
   pesados que no estén en uso.
2. Crear `config/.env` en el servidor con las credenciales reales de `hive_db`.
3. Verificar que Apache pueda **escribir** en `assets/img/` (ahí se guardan las
   imágenes que sube el director desde la app).
4. Probar que la home cargue el stream y que `api/config.php` responda `success: true`.

## 8. Más documentación

Para el detalle técnico completo (árbol de archivos función por función, decisiones de
arquitectura, riesgos conocidos), ver:

- [`DOCUMENTACION_PROYECTO.md`](DOCUMENTACION_PROYECTO.md)
- [`ESQUEMA_PROYECTO.md`](ESQUEMA_PROYECTO.md)
