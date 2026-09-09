# Correcciones 2026-09-08

## Chat: "responder a un mensaje" no sobrevivía al refresco

**Pedido:** que las burbujas del chat se amolden al tamaño del texto (cortas
cortas, largas ocupando el ancho correspondiente, como WhatsApp) y que al
contestar un mensaje puntual se muestre la cita del mensaje original (como
en la captura de referencia).

**Lo que encontré:** el frontend (`ChatBubble`, `MessageComposer`,
`chat.dart`, `directChat.dart`, `chatHistory.dart`) ya tenía **las dos
cosas implementadas**:

- `ChatBubble` ya arma la burbuja sin `minWidth`, solo con un `maxWidth`
  proporcional a la pantalla (`Container` + `Column` con
  `mainAxisSize.min` dentro de un `Flexible`), así que un mensaje corto ya
  ocupaba solo lo necesario y uno largo ya crecía hasta el máximo antes de
  saltar de línea. No hizo falta tocar nada acá.
- `ChatBubble.replyTo` / `MessageComposer.replyingTo` ya dibujaban la cita
  arriba del mensaje y arriba del campo de texto, tal cual la referencia.

El problema real estaba en el backend (`hive-backend/index.php`): la
tabla `chat_messages` sí tenía la columna `reply_to_id` (agregada en un
cambio anterior, sin terminar de conectar), pero:

- `sendChatMessage` / `sendDirectMessage` nunca guardaban el `replyTo` que
  manda el front al insertar el mensaje.
- `getAllChats` / `getDirectChat` nunca devolvían ni el `id` de cada
  mensaje ni su `replyTo`.

Por eso la cita aparecía un instante (el front la pinta de inmediato,
antes de confirmar contra el servidor, ver `_PendingMessage.replyTo`) y
desaparecía apenas se refrescaba la conversación: el mensaje "oficial" que
volvía del backend no traía la respuesta.

**Solución (solo backend):**

- `getAllChats` y `getDirectChat`: el `SELECT` ahora trae `cm.id` y hace un
  segundo `LEFT JOIN` contra la propia `chat_messages` (por
  `reply_to_id`) para traer el autor y el texto del mensaje citado. Cada
  chat devuelto ahora incluye `id` y `replyTo: { id, name, message }`
  (o `null` si no responde a nada).
- `sendChatMessage` y `sendDirectMessage`: ahora leen `replyTo` del body,
  validan que ese id exista **y pertenezca a ese mismo chat** (mismo
  equipo, o mismo hilo directo en cualquiera de los dos sentidos — así
  nadie puede citar un mensaje de una conversación ajena), y lo guardan en
  `reply_to_id` al insertar.
- Migración: el archivo que agregaba la columna estaba mal nombrado
  (`migrations/012_task_completed_at.sql`, con contenido que en realidad
  era de esto). Lo renombré a `migrations/013_chat_replies.sql` y
  actualicé la referencia en `schema.sql`. Si ya la habían corrido con el
  nombre viejo no pasa nada — es idempotente (`SET @col_exists...`), pero
  conviene tener el nombre correcto de acá en más.

Ningún archivo de Flutter cambió: el front ya estaba listo para esto, solo
le faltaba que el backend le devolviera los datos.

### Archivos tocados
- `hive-backend/index.php` (`getAllChats`, `sendChatMessage`,
  `getDirectChat`, `sendDirectMessage`)
- `hive-backend/schema.sql` (comentario de referencia a la migración)
- `hive-backend/migrations/012_task_completed_at.sql` → renombrado a
  `hive-backend/migrations/013_chat_replies.sql`

### Para producción
Si la base de datos ya existe (no es una instalación nueva desde
`schema.sql`), correr `hive-backend/migrations/013_chat_replies.sql` una
vez sobre `hive_db`.
