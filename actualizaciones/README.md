# Actualizaciones por área

Cada archivo de esta carpeta es la hoja de ruta de una rama/persona del
equipo (ver `Actualizacion.md` para el documento completo de la
reestructuración a Radio Doliv, y su tabla "Estado de la implementación").

| Rama | Archivo | Módulo asignado |
|---|---|---|
| `abraham` | [abraham.md](abraham.md) | Dashboards por rol (Director / Manager / Employee) |
| `diana` | [diana.md](diana.md) | Gestión de departamentos (UI) + Reportes y analítica |
| `jona` | [jona.md](jona.md) | Anuncios (announcements) |
| `robert` | [robert.md](robert.md) | Extensión de tareas (workflow jerárquico) + Notificaciones nuevas |
| `wen` | [wen.md](wen.md) | Permisos/leave jerárquico + Chat y Recursos por departamento |

## Reglas comunes a todas las áreas

1. **El backend real es PHP**, en `C:\xampp\htdocs\hive-backend` (Apache +
   MySQL de XAMPP, base de datos `hive_db`). La carpeta `backend/` de este
   repo es una reimplementación en Node que **no está en uso** — no la
   edites pensando que es la que corre.
2. **Toda la UI debe quedar 100% en español** (botones, diálogos, menús,
   validaciones, notificaciones). El código y los comentarios pueden estar
   en español o inglés, pero nada visible para el usuario en inglés.
3. La base organizacional (`companies`, `departments`, `role`/`position`/
   `department_id` en `users`, RBAC) ya está lista. Consulta:
   - `hive-backend/index.php` — endpoints `/user/me`, `/company/*`, `/department/*`.
   - `hive-backend/helpers.php` — `require_role()`, `require_department_manager_or_director()`.
   - `lib/models/models.dart` — `AppRole`, `UserProfile`, `DepartmentInfo`.
   - `lib/utils/session.dart` — `Session.fetchCurrentUser()` / `Session.getCachedRole()`.
4. Verifica tus cambios de backend con
   `node tools/php-backend-test.js` y `node tools/php-backend-test-org.js`
   (necesitan Apache + MySQL de XAMPP corriendo). Si agregas endpoints
   nuevos, suma tus propias verificaciones ahí o en un script nuevo con el
   mismo patrón.
5. Trabaja sobre tu propia rama y evita romper los módulos de equipos/tareas/
   chat/recursos que ya funcionan (createTeam, joinTeam, addTask, etc.).
