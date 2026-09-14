# Chat grupal: empresa + departamento

**Fecha:** 2026-09-13
**Estado:** aprobado, pendiente de plan de implementación

## Contexto

Hoy `hive-backend/chat.php` solo soporta mensajería 1 a 1 (migración 016, que
deliberadamente reemplazó una sala global insegura donde cualquiera leía todo).
Se pide reintroducir una conversación de grupo, pero esta vez con control de
acceso real: un chat de toda la empresa y un chat por departamento (si el
departamento existe).

## Decisiones (confirmadas con el usuario)

1. Los chats grupales aparecen en la MISMA bandeja "Mensajes" que los 1 a 1,
   no en una pestaña separada.
2. El Director **no** se agrega automáticamente a cada chat de departamento;
   solo entra si él mismo pertenece a ese departamento. Sí participa siempre
   en el chat de empresa (como cualquier usuario verificado).
3. Solo texto en esta versión (sin adjuntos), paridad con el chat 1 a 1 actual.
4. Los mensajes grupales sí notifican por push a los demás miembros, con la
   misma supresión que ya existe para 1 a 1 cuando ese hilo está abierto.
5. La membresía de departamento se calcula en vivo desde `users.department_id`
   (igual que el resto de reglas de departamento en la app, p. ej. tareas):
   si alguien cambia de área, pierde acceso automáticamente al chat anterior
   y gana el nuevo. El historial viejo no se borra, solo deja de ser visible
   para quien ya no pertenece a ese departamento.

## Modelo de datos

Migración `031_chat_groups.sql`.

```sql
CREATE TABLE IF NOT EXISTS chat_groups (
  id CHAR(24) PRIMARY KEY,
  kind ENUM('company','department') NOT NULL,
  ref_id CHAR(24) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_chat_group_ref (kind, ref_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS chat_group_messages (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  group_id CHAR(24) NOT NULL,
  sender_id CHAR(24) NOT NULL,
  body TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  KEY idx_cgm_group (group_id, id),
  FOREIGN KEY (group_id) REFERENCES chat_groups(id) ON DELETE CASCADE,
  FOREIGN KEY (sender_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS chat_group_reads (
  group_id CHAR(24) NOT NULL,
  user_id CHAR(24) NOT NULL,
  last_read_message_id BIGINT NOT NULL DEFAULT 0,
  PRIMARY KEY (group_id, user_id),
  FOREIGN KEY (group_id) REFERENCES chat_groups(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;
```

`ref_id` apunta a `companies.id` (kind='company') o `departments.id`
(kind='department'); no hay FK física hacia dos tablas distintas — se resuelve
en PHP según `kind`. El nombre a mostrar (nombre de empresa / nombre de
departamento) se resuelve en cada lectura via join, nunca se cachea en
`chat_groups`, para no desincronizarse si renombran la empresa o el área.

Las filas de `chat_groups` se crean **perezosamente** (get-or-create) la
primera vez que se piden — no hace falta backfill ni tocar
`createCompany`/`createDepartment`.

## Backend (`hive-backend/chat_groups.php`, nuevo módulo)

Helpers:
- `chat_group_get_or_create(PDO $pdo, string $kind, string $refId): array`
- `chat_user_groups(PDO $pdo, array $user): array` — grupos a los que
  pertenece: siempre el de empresa (si existe `companies` row), y el de su
  `department_id` si tiene uno. Ambos vía get-or-create.
- `chat_group_membership_check(PDO $pdo, array $user, array $group): bool` —
  kind='company' → true (cualquier autenticado verificado); kind='department'
  → `$user['department_id'] === $group['ref_id']`.
- `chat_group_member_emails(PDO $pdo, array $group): array` — para el
  broadcast de push: kind='company' → todos los usuarios verificados;
  kind='department' → usuarios verificados con ese `department_id`.
- `chat_group_display_name(PDO $pdo, array $group): string` — nombre de la
  empresa o del departamento vía join.

Endpoints (rutas nuevas en `index.php`, mismo estilo que `/chat/*`):
- `GET /chat/group/{id}/thread` — 404 si el grupo no existe, 403 si no eres
  miembro (`chat_group_membership_check`). Devuelve `{group:{id,name,kind},
  messages:[{id,senderId,senderName,message,createdAt,fromMe}]}`. Al leer,
  upsert de `chat_group_reads.last_read_message_id = MAX(id)` del grupo.
- `POST /chat/group/{id}/sendMessage` — body `{message}`. Mismo límite de
  4000 chars y mismo `enforce_rate_limit` que `/chat/sendMessage`. Inserta en
  `chat_group_messages` (body cifrado), y por cada miembro (menos quien
  escribe) llama `notify_user($pdo, $email, null, 'chat_group', "$sender:
  $preview", 'group', $groupId, $sender['name'], $preview)`.

`GET /chat/conversations` (modificado en `chat.php`): antepone una fila por
cada grupo de `chat_user_groups($user)`, con la forma:
```json
{"type":"group","groupId":"...","peerName":"Radio Doliv","lastMessage":"...",
 "lastAt":"...","lastFromMe":false,"unread":2}
```
(las filas 1 a 1 existentes ganan `"type":"direct"` para diferenciarlas; el
resto de sus campos no cambia). Orden final: todo junto, por `lastAt` desc;
un grupo sin mensajes aún aparece al final con `lastMessage: null`.

`notify_user()` (helpers.php): el cálculo de `collapse` pasa de
`$type === 'chat'` a `in_array($type, ['chat','chat_group'], true)`, para que
varios mensajes seguidos del mismo grupo colapsen en una sola notificación
local en vez de apilarse. `push_title_for_type('chat_group')` → mismo criterio
que `chat` (el título ya lo pisa `pushTitle` = nombre de quien escribe).

## Flutter

- `models/models.dart` (o archivo nuevo `models/chat_group.dart`): no hace
  falta un modelo grande; el `Map<String,dynamic>` crudo alcanza, igual que
  ya hace `chat_history.dart` con las conversaciones 1 a 1.
- `services/chat_service.dart` o un nuevo `services/chat_group_service.dart`:
  `fetchGroupThread(groupId)`, `sendGroupMessage(groupId, text)`.
- `shared/chat/chat_history.dart` (`ChatScreenfetch`): cada fila de
  `_conversations` ahora puede traer `type: 'group'`; el `ListTile` usa un
  ícono de grupo (`Icons.groups_rounded` en un círculo, en vez de
  `IdentityAvatar`) y el `onTap` navega a `GroupChatScreen` en vez de
  `ChatScreen` cuando `type == 'group'`.
- Nuevo `shared/chat/group_chat.dart` (`GroupChatScreen(groupId)`): calco de
  `ChatScreen`, mismo polling de 5s, mismo `MessageComposer` +
  `EmojiPickerPanel`; la única diferencia real es que `ChatBubble.username`
  usa el `senderName` de cada mensaje (no un único `peerName`) y pega contra
  `/chat/group/{id}/thread` + `/chat/group/{id}/sendMessage`.
- `PushService`: `_activeChatPeerEmail` se queda para 1 a 1; se agrega
  `_activeChatGroupId` + `setActiveChatGroup(String? id)`, llamado desde
  `GroupChatScreen.initState/dispose`. `shouldShowLocalNotification` (
  `push_messages.dart`) gana un parámetro `activeChatGroupId` y compara
  `data['type'] == 'chat_group' && data['entityId'] == activeChatGroupId`.
- `NotificationRouter`: caso nuevo `chat_group` → `GroupChatScreen(groupId:
  entityId)` cuando `entityType == 'group'` y hay `entityId`.
- `design/components/notification_tile.dart`: caso `chat_group` en `_meta`,
  mismo ícono de `chat` (`Icons.forum_outlined`) pero etiqueta "Grupo" en vez
  de "Mensaje", para diferenciarlo de un aviso de chat 1 a 1 en la lista de
  notificaciones.

## Fuera de alcance

- Adjuntar imágenes/archivos en chats grupales.
- Silenciar/salir de un chat grupal (la membresía es automática y no
  configurable).
- Chats por sub-equipo (`sub_teams`) — solo empresa y departamento, como se
  pidió.
- Lista de miembros / info del grupo dentro del hilo.
- Migrar o mostrar los mensajes de `chat_messages_legacy_global` (siguen sin
  leerse, ver migración 016).

## Testing

Backend (`hive-backend/scratchpad` o similar, vía curl contra la BD viva,
mismo estilo que las pruebas de fases anteriores):
- Chat de empresa visible y escribible por cualquier usuario verificado.
- Chat de departamento: 403 al leer/escribir si `department_id` no coincide.
- Cambiar de departamento mueve el acceso (deja de ver el viejo, ve el nuevo).
- `unread` sube con mensajes ajenos y baja a 0 tras abrir el hilo.
- Broadcast de `notify_user` llega a todos los miembros menos al remitente.

Flutter (`flutter test`):
- `chat_history_tile_test.dart` (o nuevo) cubre una fila de tipo grupo en la
  bandeja.
- Nuevo `group_chat_test.dart` para `GroupChatScreen` (carga, envío, burbujas
  con nombre de remitente).
- `push_messages_test.dart` cubre la supresión por `chat_group` +
  `activeChatGroupId`.
