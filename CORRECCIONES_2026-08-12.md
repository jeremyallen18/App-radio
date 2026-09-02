# Correcciones aplicadas (2026-08-12)

## 1. Botón "Ver equipo" después de enviar invitaciones
Antes, al invitar miembros (`Crear equipo → seleccionar áreas → Invitar
miembros`), la única forma de llegar al equipo recién creado era volver
atrás con el botón "Regresar" hasta perder toda la pila de pantallas
intermedias.

**Corregido** en `lib/create&join-Team/Domain-team.dart`
(`InviteMembersScreen`):
- Después de enviar una invitación con éxito aparece un botón **"Ver
  equipo"**.
- Al tocarlo, se trae el equipo actualizado (`GET /team/showTeams`) y se
  navega directo a su detalle (`t_detail`) con
  `Navigator.pushAndRemoveUntil`, eliminando de la pila las pantallas de
  "Crear equipo", "Áreas" e "Invitar miembros". Así, si luego el usuario
  presiona "atrás" desde el detalle del equipo, vuelve directo a la
  pantalla principal en lugar de tener que atravesar de nuevo el flujo de
  creación.

## 2. Una sola base de datos, sin SQL duplicado
El proyecto ya usaba una única base de datos (`hive_db`, MySQL/MariaDB vía
PDO en `hive-backend/config.php`) — no había un segundo motor ni una
segunda base. El problema real era que **el esquema estaba definido dos
veces**: `hive-backend/schema.sql` y `hive-backend/setup_database.sql`
tenían prácticamente las mismas 13 tablas copiadas y pegadas, y
`setup_database.sql` además creaba un usuario de MySQL (`hive_user`) que
no coincidía con lo que indica el `README` (usuario `root` de XAMPP) ni
con el `.env` real del proyecto.

**Corregido:**
- Se eliminó `hive-backend/setup_database.sql`. `hive-backend/schema.sql`
  queda como el **único** script de esquema del proyecto (así lo usa el
  `README` desde el principio:
  `mysql -u root -p < hive-backend/schema.sql`).
- Se agregó una nota al inicio de `schema.sql` aclarando que es la única
  fuente de verdad del esquema, y qué hacer si alguien quiere un usuario
  de MySQL dedicado en vez de `root`.
- Se corrigió `hive-backend/.env.example`, que tenía credenciales de
  `hive_user` que ya no se crean en ningún lado (y que nunca coincidieron
  con las instrucciones del `README`). Ahora sus valores de ejemplo son
  `root` sin contraseña, igual que la configuración estándar de XAMPP que
  describe el `README` y que ya usan los defaults de `config.php`.
- Las migraciones en `hive-backend/migrations/` (para bases de datos ya
  instaladas) no se tocaron: no duplican el esquema, son pasos
  incrementales documentados como innecesarios para instalaciones nuevas.

## Archivos tocados
- `lib/create&join-Team/Domain-team.dart` (botón "Ver equipo")
- `hive-backend/schema.sql` (nota de fuente única de verdad)
- `hive-backend/setup_database.sql` (eliminado)
- `hive-backend/.env.example` (credenciales por defecto consistentes con
  el README y `config.php`)
