# Mi parte — qué falta

Recordatorio de lo que queda por hacer, según los objetivos específicos de
[Proyecto-DolivManager.md](Proyecto-DolivManager.md) y el estado real del
repo al día de hoy.

## Objetivos específicos — estado

| Objetivo | Estado | Notas |
|---|---|---|
| Diseñar una interfaz móvil intuitiva para administradores y empleados | **En progreso** | Sistema de diseño (`lib/design/`) aplicado en `login.dart`, `tasks.dart`, `teamDetail.dart`, `profile.dart`, `bottomnavbar.dart`, `teams.dart`. El resto de las pantallas todavía usa colores sueltos — ver [Rediseno-Frontend.md](Rediseno-Frontend.md) para el orden pendiente. |
| Desarrollar un backend basado en una API para gestión centralizada | **Hecho** | PHP + PDO en [`hive-backend/`](hive-backend/), router en `index.php`, autenticación por token. |
| Implementar una base de datos estructurada para almacenamiento seguro | **Hecho** | MySQL `hive_db`, esquema en `hive-backend/schema.sql` + `migrations/`. |
| **Integrar la app móvil con el sitio web oficial de Radio Doliv** | ❌ **Sin empezar** | No hay ningún endpoint, credencial ni código en el repo que hable con el sitio web institucional. Es el objetivo pedido expresamente por el dueño de Radio Doliv (ver justificación) y el que menos avance tiene. |
| Mecanismos básicos de autenticación y control de acceso | **Hecho** | Token opaco (`users.token`), `password_hash`, y RBAC por rol (`director`/`manager`/`employee`) vía `require_role()` / `require_department_manager_or_director()`. |

## Módulos funcionales pendientes (de [Actualizacion.md](Actualizacion.md))

Estos son los módulos que la reestructuración organizacional dejó abiertos —
por ahora **ninguno tiene equipo/persona confirmada** en la tabla de
seguimiento del repo:

- [ ] **Dashboards por rol** (Director / Manager / Employee) — ver [actualizaciones/abraham.md](actualizaciones/abraham.md).
- [ ] **Gestión de departamentos (UI) + Reportes y analítica** — ver [actualizaciones/diana.md](actualizaciones/diana.md).
- [ ] **Anuncios (announcements)** — ver [actualizaciones/jona.md](actualizaciones/jona.md).
- [ ] **Extensión de tareas** (workflow Director → Manager → Employee) **+ Notificaciones nuevas** — ver [actualizaciones/robert.md](actualizaciones/robert.md).
- [ ] **Leave requests jerárquico + Chat y Recursos por departamento** — ver [actualizaciones/wen.md](actualizaciones/wen.md).

## Ya resuelto en esta sesión

- [x] Guía de instalación simplificada: sin ZIP duplicado, backend servido vía `Alias` de Apache en vez de junction/copia.
- [x] Eliminado el botón de registro con Google en `signup.dart` (llamaba a un endpoint stub que devolvía 501).
- [x] Corregido el bug de sesión: `Login` usaba `Navigator.pushNamed` en vez de limpiar el stack, así que al retroceder la app volvía al login con los campos llenos.

## Próximo paso sugerido

Definir con el dueño de Radio Doliv **cómo** se debe integrar con el sitio
web (¿API del CMS del sitio? ¿WordPress? ¿FTP/webhook?) — sin esa
definición no se puede arrancar el objetivo 4, que es el que el cliente pidió
explícitamente.
