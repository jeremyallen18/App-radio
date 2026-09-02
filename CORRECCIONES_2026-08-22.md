# Correcciones 2026-08-22

## "Mensajes": burbujas de mensajes sin leer, tipo WhatsApp

**Pedido:** en la lista de "Mensajes" (`messagesDashboard.dart`), mostrar
una burbuja de notificación en los chats que todavía no se contestaron
(como en WhatsApp); y en el botón "Mensajes" del inicio, mostrar el total
de mensajes sin leer (como el ícono de una app con el conteo en rojo).

**Problema de fondo:** el backend nunca guardaba si un mensaje había sido
"leído" o no — `chat_messages` no tenía ese concepto, así que no había de
dónde sacar un número de no leídos.

**Solución:**

- Backend (`hive-backend/`):
  - Nueva tabla `chat_reads` (`schema.sql`,
    `migrations/008_chat_read_status.sql`): guarda, por usuario y por chat
    (`chat_key` = `team:<teamId>` o `direct:<peerEmail>`), hasta qué
    momento (`last_read_at`) leyó ese chat.
  - Nuevo endpoint `POST /chat/read` (`markChatRead`): marca un chat como
    leído hasta ahora. Lo llaman `chat.dart` y `directChat.dart` al abrir
    la conversación y en cada refresco mientras siguen abiertas.
  - `GET /chat/list` (`listChats`) ahora agrega `unreadCount` a cada chat:
    mensajes que no escribió el usuario y son más nuevos que su
    `chat_reads` para ese chat (si nunca entró, cuentan todos).

- Frontend (`lib/`):
  - Nuevo componente `UnreadCountBadge`
    (`lib/design/components/unread_count_badge.dart`): burbuja roja
    circular con el número (se corta en "99+"); no se muestra si el
    conteo es 0.
  - `lib/screens/messagesDashboard.dart`: cada fila de chat muestra su
    burbuja de no leídos junto a la hora, y resalta el último mensaje en
    negrita mientras el chat siga sin leerse.
  - `lib/home_page/home_page_home.dart`: el botón "Mensajes" ahora suma el
    `unreadCount` de todos los chats (`GET /chat/list`) y lo muestra en una
    burbuja sobre el botón; se refresca cada 15 s y al volver de la
    pantalla de Mensajes.

**Importante para producción:** hay que correr
`hive-backend/migrations/008_chat_read_status.sql` sobre la base de datos
existente (las instalaciones nuevas ya parten de `schema.sql`, que ya
incluye `chat_reads`).
