# Área: Gestión de departamentos (UI) + Reportes y analítica (rama `diana`)

## Parte 1 — Gestión de departamentos (UI)

### Punto de partida (ya existe, no lo dupliques)

Backend PHP ya implementado en `hive-backend/index.php`:

- `POST /company/create` `{ name, description?, logo? }` — solo si aún no
  existe empresa; el que la crea queda como `director`.
- `GET /company/info`, `POST /company/update` (solo director).
- `POST /department/create` `{ name, description? }` (solo director).
- `GET /department/list` → `{ departments: [{ id, companyId, name,
  description, managerEmail, employeeCount }] }`.
- `POST /department/assignManager/{departmentId}` `{ email }` (solo
  director) — el usuario destino queda con `role=manager`.
- `POST /department/assignEmployee/{departmentId}` `{ email, position? }`
  (director, o el manager del propio departamento) — asigna/mueve un
  empleado.

### Tareas

- [ ] Pantalla para el Director: crear/editar la empresa (nombre,
      descripción, logo) si aún no existe (`/company/create`).
- [ ] Pantalla para el Director: listar departamentos, crear uno nuevo,
      asignar/reasignar manager.
- [ ] Pantalla para Director y Manager: agregar/mover empleados dentro de un
      departamento (usa `/department/assignEmployee`), con el campo
      `position` (cargo: "Ingeniero de Software", "Radio Host", etc.).
- [ ] Manejar los errores tal cual los da el backend (403 sin permiso, 404
      departamento/usuario no encontrado, 409 nombre duplicado, 400 datos
      inválidos) mostrando mensajes en español.
- [ ] Todo el texto visible en español.

## Parte 2 — Reportes y analítica

### Tareas

- [ ] Backend: crear tabla `reports` en `hive-backend/schema.sql` +
      migración (sigue el patrón de
      `hive-backend/migrations/001_org_structure.sql`) con columnas
      `employee_id`/`email`, `manager_email`, `week`, `performance`,
      `comments` (ver `Actualizacion.md`, sección "Reports").
- [ ] Endpoints PHP nuevos (agrégalos a `index.php`, siguiendo el estilo de
      `require_auth`/`require_role` ya usado): crear reporte semanal
      (manager sobre su equipo), listar reportes por departamento (manager
      ve solo el suyo, director ve todos).
- [ ] Dashboard: tareas por departamento, completadas, pendientes,
      productividad por empleado/departamento, estadísticas semanales/
      mensuales. El Director ve todo; el Manager solo su departamento —
      aplica el mismo criterio que `require_department_manager_or_director()`
      en `helpers.php`.
- [ ] Verifica con un script en `tools/` siguiendo el patrón de
      `tools/php-backend-test-org.js`.

## Cómo probar

- `node tools/php-backend-test-org.js` sigue en 100% (no debe romperse).
- `flutter analyze` sin errores nuevos.
