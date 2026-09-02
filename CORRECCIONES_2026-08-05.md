# Correcciones aplicadas (2026-08-05)

Resumen de lo que se revisó y corrigió a partir de tu pedido. La mayoría de
lo pedido (chat por equipo, notificaciones, botón de renunciar) ya existía
en el proyecto de una sesión anterior; aquí se corrigieron los bugs reales
que impedían que funcionara bien de punta a punta, y se completó lo que
faltaba.

## 1. Chat por equipo — ya funcionaba, verificado
- Cada equipo tiene su propio hilo en `chat_messages.team_id`. Solo sus
  integrantes pueden leerlo/escribirlo (`hive-backend/index.php`:
  `getAllChats` / `sendChatMessage`, protegidos con `require_team_member`).
- Frontend: `lib/screens/chat.dart` (chat en vivo, polling cada 3s) y
  `lib/screens/chatHistory.dart` (historial de solo lectura).
- **Mejora**: se agregó un índice `idx_chat_messages_team` para que la
  consulta que arma el chat de cada equipo sea rápida a medida que crecen
  los mensajes (antes no tenía índice sobre `team_id`).

## 2. El bug real: el creador de un equipo no siempre se veía como admin
En `lib/screens/teamDetail.dart`, quién es el líder/admin se decidía
comparando `email == leaderEmail`. El problema: `email` se inicializaba con
una variable global (`name`) que **solo se llenaba al visitar la pestaña
"Equipos"**, y esa variable se pierde cada vez que se reinicia la app.
Resultado: quien acababa de crear un equipo, o quien reabría la app y
entraba directo a un equipo, a veces no se reconocía como admin hasta
navegar en cierto orden.

**Corregido:**
- `lib/utils/session.dart`: ahora cachea el correo del usuario en
  almacenamiento seguro (persiste entre reinicios), no solo el rol.
- `lib/screens/teamDetail.dart`: nuevo método `_loadMyEmail()` que resuelve
  "quién soy" de forma confiable — variable en memoria si ya está, si no el
  correo cacheado, y si no existe se pide a `/user/me`. Así el creador de un
  equipo se reconoce como admin **al instante**, en tiempo real, sin
  depender de haber visitado antes otra pantalla.
- De paso se corrigió un antipatrón real de Flutter: `build()` llamaba
  `setState()` dentro de sí mismo en cada reconstrucción (puede lanzar
  "setState() or markNeedsBuild() called during build"), y había un
  `FutureBuilder` que nunca recibía su `Future` (`_futureData` no se
  asignaba nunca). Ambos se limpiaron; además se agregó "desliza para
  refrescar" en el detalle del equipo.

## 3. Notificaciones
Ya existía la tabla `notifications` y se emitían para: agregado a un
equipo, tarea asignada, mensaje nuevo en el chat, alguien salió del equipo,
nuevo líder, equipo eliminado. Se revisó todo el flujo (backend + pantalla
`lib/screens/notifications.dart` + campanita en `lib/models/appbar.dart`) y
se mejoró:
- **Antes**, cuando alguien renunciaba solo se avisaba al líder. **Ahora**
  se avisa a todo el equipo (`hive-backend/index.php`, `resignFromTeam`).
- Se agregó actualización automática (polling) del contador de
  notificaciones en la campanita del appbar (cada 15s) y en la pantalla de
  notificaciones (cada 8s, sin tapar la lista con el spinner), para que se
  sienta en tiempo real sin tener que entrar y salir de la pantalla.

## 4. Salir del equipo solo por botón "Salir/Renunciar"
Ya estaba bien resuelto: la única forma de que un miembro deje de
pertenecer a un equipo por su cuenta es el botón **"Renunciar"**
(`lib/screens/MResign.dart` → `POST /team/resign/{teamId}`), que exige
sesión propia y no permite que el líder se auto-elimine sin transferir el
liderazgo antes. El líder solo puede sacar a otros desde "Gestionar
miembros" (`lib/screens/manageMembers.dart` → `POST
/team/deleteMember/{teamId}`), y esa acción también está protegida en el
backend (`require_team_leader`). No hay otra vía para salir de un equipo.

(Nota: el botón "Salir" que ves junto a "Renunciar" abre una pantalla
distinta — solicitud de permiso/ausencia, no salida del equipo — es una
función aparte que ya existía.)

## 5. Base de datos nueva
- `hive-backend/schema.sql`: esquema completo y actualizado (ya incluía
  todo lo necesario: equipos, chat por equipo, notificaciones, tareas,
  permisos, estructura organizacional). Se le agregaron los índices
  mencionados arriba.
- **Nuevo:** `hive-backend/setup_database.sql` — un solo archivo que crea
  el usuario de base de datos, la base `hive_db` y **todas** las tablas
  desde cero. Pensado para correr una sola vez en un servidor limpio:
  ```bash
  mysql -u root -p < hive-backend/setup_database.sql
  ```
  (o importarlo tal cual desde phpMyAdmin). Cambia la contraseña de
  ejemplo antes de usarlo en producción.
- **Nuevo:** `hive-backend/.env.example` — plantilla de variables de
  entorno para copiar a `.env`.
- **Nuevo:** `hive-backend/migrations/004_chat_notifications_indexes.sql`
  — para aplicar los índices nuevos sobre una base de datos que ya tenías
  corriendo (sin perder datos).

## Archivos tocados
- `hive-backend/index.php` (notificación de renuncia a todo el equipo)
- `hive-backend/schema.sql` (índices)
- `hive-backend/setup_database.sql` (nuevo)
- `hive-backend/.env.example` (nuevo)
- `hive-backend/migrations/004_chat_notifications_indexes.sql` (nuevo)
- `lib/utils/session.dart` (caché de correo)
- `lib/screens/teamDetail.dart` (bug de identidad del admin + setState en
  build + refresco manual)
- `lib/screens/dashboard.dart` (cachea el correo también aquí)
- `lib/models/appbar.dart` (polling del contador de notificaciones)
- `lib/screens/notifications.dart` (polling en la pantalla de notificaciones)
