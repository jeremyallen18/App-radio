# Área: Anuncios / Announcements (rama `jona`)

## Objetivo

Módulo nuevo y autocontenido: anuncios de empresa (visibles para todos) y
anuncios de departamento (visibles solo para ese departamento).

## Diseño de referencia (`Actualizacion.md`, sección "Announcements")

```
announcements
  id
  title
  content
  department_id   -- NULL = anuncio de toda la empresa
  created_by
  created_at
```

## Tareas — Backend (PHP, `hive-backend/`)

- [ ] Agregar la tabla `announcements` a `hive-backend/schema.sql` (respeta
      el estilo `CHAR(24)` para ids, ver cómo se generan con
      `generate_id()` en `helpers.php`) y crear una migración numerada en
      `hive-backend/migrations/` (sigue el patrón de
      `001_org_structure.sql`). Aplícala contra `hive_db` igual que se hizo
      esa (PDO desde PHP CLI, o el cliente que prefieras).
- [ ] Endpoints nuevos en `index.php`:
  - `POST /announcements/create` — body `{ title, content, departmentId? }`.
    Solo `director` puede crear anuncios de empresa (`departmentId` vacío).
    `director` o el `manager` del departamento pueden crear anuncios de ese
    departamento — reutiliza `require_department_manager_or_director()` de
    `helpers.php`.
  - `GET /announcements/list` — devuelve los anuncios de empresa +
    (si el usuario tiene `department_id`) los de su propio departamento.
  - Considera emitir una notificación in-app con `notify_user()` (ya
    existe) del tipo `new_announcement` a los usuarios del departamento (o
    a todos si es de empresa).
- [ ] Autenticación con `require_auth()`, igual que el resto del backend.

## Tareas — Flutter

- [ ] Pantalla de lista de anuncios (empresa + departamento), accesible
      desde los 3 dashboards (coordina con Abraham en qué sección va).
- [ ] Formulario de creación para Director/Manager, con validación y
      mensajes en español.
- [ ] Modelo `Announcement` en `lib/models/models.dart` (id, title, content,
      departmentId, createdBy, createdAt).

## Cómo probar

- Crea un script `tools/php-backend-test-announcements.js` siguiendo el
  patrón de `tools/php-backend-test-org.js` (usuarios marcados
  `zz_annit_...@test.invalid`, limpieza al final).
- No debe romper `node tools/php-backend-test.js` ni
  `node tools/php-backend-test-org.js`.
- Todo el texto visible en español.
