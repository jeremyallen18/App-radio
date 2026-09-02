# Correcciones aplicadas (2026-08-12, segunda tanda)

## "Gestionar miembros": invitar y sacar miembros

Reporte: en "Gestionar miembros" no dejaba invitar nuevos usuarios ni
mostraba la lista completa de miembros para poder sacarlos, con errores
404.

Revisé el flujo completo (pantalla → backend → base de datos):
`lib/screens/manageMembers.dart` ya apuntaba a las rutas correctas del
backend (`POST /team/addMember/{teamId}`, `POST
/team/deleteMember/{teamId}`), y esas rutas ya existían y estaban bien
registradas en `hive-backend/index.php`. El problema real era que la
lista de miembros que ve esta pantalla se pasaba "de memoria" desde
`teamDetail.dart`, y si esa copia se había quedado desactualizada (por
ejemplo, el equipo se abrió desde una lista que no se había vuelto a
cargar), la pantalla no reflejaba lo que realmente había en la base de
datos — y al intentar sacar a alguien que ya no estaba ahí, el backend
respondía `404` (a propósito, para no fingir un éxito que no ocurrió).

**Corregido**, todo en `lib/screens/manageMembers.dart`:
- Al abrir la pantalla, además de mostrar de entrada la lista que llegó
  por parámetro, se pide inmediatamente la versión más reciente al
  backend (`GET /team/showTeams`) y se reemplaza la lista con esa — así
  "Miembros del equipo" siempre coincide con la base de datos, sin
  importar desde dónde se haya llegado a esta pantalla. También se agregó
  "deslizar para refrescar" por si se quiere forzar una actualización
  manual.
- Agregar miembro (`_addMember`) y sacar miembros (`_removeSelected`)
  ahora mandan el cuerpo como JSON con `Content-Type: application/json`,
  igual que el resto de la app (antes eran los únicos dos lugares que
  mandaban form-urlencoded implícito), por consistencia.
- Manejo explícito de cada código de respuesta:
  - `403` → mensaje claro ("Solo el líder del equipo puede…") en vez de
    un número de error genérico.
  - `404` al sacar un miembro → ya no se muestra como fallo: si esa
    persona ya no estaba en el equipo, el resultado que le importa al
    usuario (que no esté ahí) ya se cumplió, así que se trata como éxito
    y se refresca la lista en silencio.
  - `404` al agregar un miembro (equipo inexistente) → mensaje explícito
    y se regresa a la pantalla anterior en vez de dejar al usuario
    reintentando algo que no puede funcionar.
  - `409` (persona ya en el equipo) → se refresca la lista además de
    avisar, por si la pantalla no lo tenía reflejado todavía.

## Bug de rutas de archivo (mayúsculas/minúsculas)

Encontré, aparte de lo reportado, un bug real de rutas: la carpeta del
proyecto es `lib/utils/` (minúscula), pero 6 archivos la importaban como
`Utils/` (con mayúscula):
`lib/home_page/teams.dart`, `lib/home_page/profile.dart`,
`lib/screens/MResign.dart`, `lib/screens/LResign.dart`,
`lib/screens/MarkTaskDone.dart`, `lib/screens/signup.dart`. Esto compila
sin problema en Windows/macOS (sistemas de archivos que no distinguen
mayúsculas), pero **falla en Linux** (por ejemplo, un pipeline de CI o
cualquier build corrido desde una máquina Linux) con un error de "no se
encuentra el archivo". Se corrigieron los 6 imports a `utils/Routes.dart`.

## Limpieza: pantalla duplicada sin usar
`lib/screens/LResign.dart` (clase `Resign`) era una pantalla vieja de
"Eliminar miembro / Asignar nuevo líder" que ya no estaba enlazada desde
ningún lado del código — quedó reemplazada hace tiempo por
`lib/screens/manageMembers.dart` y `lib/screens/MResign.dart`, pero nunca
se borró. Se eliminó por completo para no dejar código muerto que pueda
confundir a futuro.

## Archivos tocados
- `lib/screens/manageMembers.dart` (refresco desde servidor, JSON,
  manejo de 403/404/409)
- `lib/home_page/teams.dart`, `lib/home_page/profile.dart`,
  `lib/screens/MResign.dart`, `lib/screens/MarkTaskDone.dart`,
  `lib/screens/signup.dart` (import `utils/Routes.dart` corregido)
- `lib/screens/LResign.dart` (eliminado, código muerto)
