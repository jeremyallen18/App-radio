# Auditoría — control de acceso a documentos e imágenes subidas

Fecha: 2026-09-09
Alcance: endpoints y almacenamiento de `hive-backend` para el apartado
"Recursos → Documentos" e "Imágenes del equipo".

## Documentos de equipo — SEGURO

Almacenamiento: `DOCUMENT_DIR = hive-backend/private/documents/`
(`config.php:125`).

- `hive-backend/private/.htaccess` → `Require all denied` (y `Deny from all` de
  respaldo). El directorio **no se sirve nunca por HTTP directo**.
- El `.htaccess` raíz deja pasar archivos reales (`RewriteCond %{REQUEST_FILENAME}
  -f`), pero eso no aplica a `private/` porque ese subdirectorio lo bloquea su
  propio `.htaccess`.

Endpoints (`documents.php`, rutas en `index.php:71-74`):

| Handler | Auth | Autorización | Notas |
|---|---|---|---|
| `teamDocumentsList` | `require_auth` | `require_team_member` | Solo miembros del equipo ven la lista. |
| `teamDocumentUpload` | `require_auth` | `require_team_member` | Valida extensión (lista blanca), tamaño ≤ 25 MB, `finfo` MIME. Nombre en disco generado por el servidor (`random_bytes(16)`), nunca el del cliente. |
| `teamDocumentDownload` | `require_auth` | `require_team_member` (sobre `doc['team_id']`) | `basename($doc['stored_path'])` evita path traversal. Si el archivo no está en disco → `error_response('El archivo ya no está disponible en el servidor.', 404)` — mensaje limpio, **sin ruta**. Cabeceras `X-Content-Type-Options: nosniff`, `Cache-Control: private, no-store`, `Content-Disposition: attachment` con el nombre original saneado de comillas. |
| `teamDocumentDelete` | `require_auth` | `require_team_member` **y** (subidor `||` `is_team_leader`) | 403 si no cumple. Borra fila + archivo. |

**Veredicto:** correcto. No requiere cambios. El cliente Flutter
(`DocumentService` / `TeamDocumentsScreen`) siempre manda `Authorization` y ahora
comprueba `statusCode` antes de escribir el archivo temporal (Tasks 3-4), así que
un 404 no genera un archivo vacío ni fuga de ruta.

## Imágenes de equipo — ACEPTABLE POR DISEÑO, con una salvedad

Almacenamiento: `UPLOAD_DIR = hive-backend/uploads/` (`config.php:105`), **dentro
del árbol web**. El `.htaccess` raíz deja pasar `uploads/` sin reescritura
(comentario explícito: *"Let real files/dirs (uploads/, etc.) pass through
untouched"*). No hay `uploads/.htaccess`.

Endpoints (`legacy_teams.php`, rutas en `index.php:65-66`):

| Handler | Auth | Autorización | Notas |
|---|---|---|---|
| `showImage` | `require_auth` | `require_team_member` | Devuelve `[{imgURL, imgName}]`. `imgURL = UPLOAD_URL_BASE . img_path` → `http://host/hive-backend/uploads/<hex32>.<ext>`. |
| `addImage` | `require_auth` | `require_team_member` | Lista blanca `jpg/jpeg/png/gif/webp` + `getimagesize()`. Nombre en disco = `bin2hex(random_bytes(16))` + ext. |

**Salvedad:** la imagen en sí se sirve como **archivo estático público**. La
lista solo se entrega a miembros del equipo, pero la URL resultante no valida
pertenencia: quien tenga la URL (nombre aleatorio de 32 hex, no adivinable) puede
descargarla sin ser del equipo — estilo *capability URL*. Es el mismo
comportamiento que el proyecto de referencia (`App-radio-robert`).

- Riesgo: bajo. La URL solo se conoce si el backend ya te la dio (eres miembro) o
  alguien te la reenvía. El nombre aleatorio impide enumeración.
- No hay endpoint para borrar una imagen en el backend actual (el fork sí lo
  tenía). Fuera de alcance.

**Recomendación (no implementada aquí, fuera de alcance):** si se quiere paridad
con los documentos, servir las imágenes por un handler autenticado
(`GET /image/file/{id}` con `require_team_member`) y mover `uploads/` a
`private/`. Es un cambio de contrato (`imgURL` pasaría a ser una ruta de API con
token) que toca el visor, la grilla y "Ver recursos publicados"; se deja
documentado para decidir aparte.

## Descarga de imagen desde el visor (Task 5)

`ImageDetailScreen._download()` hace `http.get(imageUrl)` **sin** cabecera
`Authorization`. Es correcto dado que `imgURL` es una URL estática pública; añadir
el token no cambiaría nada. Si en el futuro se adopta la recomendación de arriba,
habrá que pasar `Authorization` aquí y en la grilla (`Image.network` con
`headers:`).

## Resumen

- Documentos: control de acceso correcto de punta a punta. Sin cambios.
- Imágenes: autenticadas en el listado y la subida; el archivo se sirve como
  asset público con nombre no adivinable (aceptable por diseño, igual que el
  fork). Endurecerlo es un cambio de contrato aparte, documentado arriba.
- Ningún endpoint filtra rutas del servidor en errores.
