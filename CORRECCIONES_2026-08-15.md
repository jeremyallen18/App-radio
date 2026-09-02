# Cambios aplicados (2026-08-15)

## Nuevo: botón "Mensajes" + dashboard de chats tipo WhatsApp

Pedido: un botón ancho (de lado a lado), debajo de los 3 botones de
Resumen ("Pendientes / Completadas / Equipos") tanto en "Inicio" como en
"Perfil", que lleve a una lista de chats — de equipo y directos — desde
donde se pueda entrar a cada uno y mandar/recibir mensajes con
normalidad.

### Backend (`hive-backend/index.php`)
- **Nuevo endpoint** `GET /chat/list`, función `listChats`: junta en una
  sola lista los equipos a los que pertenece el usuario (`team_members`,
  igual que `showTeams`) y las conversaciones directas en las que
  participa (`chat_messages` con `team_id IS NULL`, agrupando por "la
  otra persona" del hilo). Cada entrada trae `type` (`team`/`direct`),
  `id` (teamId o correo), `title`, `photoUrl`, y el último mensaje
  (`lastMessage`, ya formateado tipo WhatsApp: "Tú: ...", "Nombre: ..."
  en grupos, o el mensaje solo en directos) con su fecha
  (`lastMessageAt`). Se ordena por más reciente primero; los chats sin
  mensajes todavía van al final. No se crean tablas nuevas — reutiliza
  `chat_messages`, `teams` y `team_members` tal cual ya existían.
- Probado end-to-end con un servidor real (PHP built-in server +
  MariaDB): login, chat de equipo, chat directo y `chat/list` con los
  datos combinados y en el orden esperado, sin romper los endpoints de
  chat que ya existían (`getAllChats`, `sendMessage`, `direct`).

### Frontend (Flutter)
- **Nuevo** `lib/screens/messagesDashboard.dart` (`MessagesDashboardScreen`):
  pantalla tipo WhatsApp que llama a `GET /chat/list` y muestra cada chat
  como una fila (avatar + nombre + vista previa del último mensaje +
  hora), con "deslizar para refrescar", y los estados de carga/vacío/error
  ya usados en el resto de la app (`LoadingState`, `EmptyState`,
  `ErrorState`). Al tocar una fila:
  - si es de equipo → abre `ChatScreen` (chat.dart) con ese `teamId`.
  - si es directa → abre `DirectChatScreen` (directChat.dart) con ese
    `peerEmail`.
  Ninguna de esas dos pantallas se modificó: ya mandan y reciben mensajes
  correctamente (ver `CORRECCIONES_2026-08-05.md`), este dashboard solo
  decide a cuál entrar.
- **`lib/home_page/home_page_home.dart`** ("Inicio") y
  **`lib/home_page/profile.dart`** ("Perfil"): se agregó, debajo de la
  fila de 3 `StatTile` (Pendientes/Completadas/Equipos), un botón
  `AppButton` envuelto en `SizedBox(width: double.infinity)` con el
  texto "Mensajes", que abre `MessagesDashboardScreen`.

### Archivos tocados
- `hive-backend/index.php` (nuevo endpoint `chat/list` + función
  `listChats`/`chat_preview`)
- `lib/screens/messagesDashboard.dart` (nuevo)
- `lib/home_page/home_page_home.dart` (botón "Mensajes")
- `lib/home_page/profile.dart` (botón "Mensajes")

## "Volver a asignar tarea": permitir reasignar a la misma persona

Reporte: el diálogo "Volver a asignar tarea" no dejaba elegir y confirmar
a la misma persona que ya tenía la tarea asignada.

Encontré el bloqueo en dos capas, ambas corregidas:

- **Frontend** (`lib/screens/teamDetail.dart`, `_openReassignDialog`): el
  botón "Reasignar" se deshabilitaba explícitamente cuando la persona
  elegida (`selected`) era igual a quien ya tenía la tarea
  (`currentAssignee`). Se quitó esa condición del `onPressed`, dejando
  solo que haya alguien seleccionado.
- **Backend** (`hive-backend/index.php`, `updateTeamTask`): aunque el
  frontend hubiera dejado pasar la petición, el backend descartaba la
  reasignación si el correo enviado coincidía con el que ya tenía la
  tarea (`$newEmail !== $task['email']`), así que no actualizaba nada ni
  mandaba la notificación de "se te asignó esta tarea". Ahora cualquier
  `email` presente en el body se trata como reasignación válida, sin
  importar si es la misma persona.

Probado end-to-end (servidor real): reasignar a otra persona, reasignar
dos veces seguidas a la misma persona, y volver a la persona original —
las tres devuelven `200 Task updated` y el cambio queda guardado.

### Archivos tocados
- `hive-backend/index.php` (`updateTeamTask`)
- `lib/screens/teamDetail.dart` (`_openReassignDialog`)
