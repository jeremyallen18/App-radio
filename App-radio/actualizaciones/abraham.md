# Área: Dashboards por rol (rama `abraham`)

## Objetivo

Reemplazar el dashboard único actual por tres dashboards distintos según el
rol del usuario autenticado: **Director**, **Manager** y **Employee**.

## Punto de partida (ya existe, no lo dupliques)

- `lib/models/models.dart`: enum `AppRole` (`director`/`manager`/`employee`),
  clase `UserProfile` (name, email, role, position, department).
- `lib/utils/session.dart`: `Session.fetchCurrentUser(token)` (llama a
  `GET /user/me`) y `Session.getCachedRole()` (lee el rol cacheado tras el
  login, sin red).
- `lib/screens/login.dart` ya cachea el rol en segundo plano al iniciar
  sesión.
- Backend: `GET /user/me` devuelve `{ id, name, email, role, position,
  department: { id, companyId, name, description, managerEmail,
  employeeCount } | null }`.

## Tareas

- [ ] Definir el punto de entrada: tras el login (o al abrir
      `BottomNavBar`/`homescreen.dart`), leer `Session.getCachedRole()` y
      enrutar a una de tres pantallas nuevas. Si es `null` (falló el fetch
      o el usuario es muy antiguo), tratar como `employee` por defecto.
- [ ] **Dashboard Director** — pantalla nueva con: resumen de la empresa,
      lista de departamentos, empleados, tareas activas, gráficas de
      desempeño, aprobaciones de permisos pendientes, anuncios de empresa,
      reportes. (Varias de estas secciones dependen de módulos que otras
      áreas están construyendo — dejar la sección con un estado vacío/"Próximamente"
      si el módulo de origen todavía no existe, en vez de bloquear tu propia entrega.)
- [ ] **Dashboard Manager** — resumen del departamento propio (usar
      `UserProfile.department`), empleados del departamento, tareas
      pendientes/completadas, recursos del departamento, anuncios del
      departamento, chat.
- [ ] **Dashboard Employee** — mis tareas, mi progreso, mi calendario, mis
      anuncios, chat del departamento, recursos compartidos, solicitudes de
      permiso. Puede reutilizar bastante de `lib/home_page/*` ya existente.
- [ ] Todo el texto visible en español (títulos de sección, estados vacíos,
      errores).
- [ ] Actualizar `lib/utils/Routes.dart` con las rutas de los 3 dashboards
      si hace falta navegación directa (deep link, back button, etc.).

## Fuera de alcance para esta área (no lo implementes aquí)

- Los endpoints de departamentos/anuncios/reportes en sí — solo consume lo
  que ya exista; si necesitas un endpoint que no existe todavía, coordina
  con el área responsable (ver `actualizaciones/README.md`).

## Cómo probar

- `flutter analyze` sin errores nuevos.
- Iniciar sesión con tres usuarios de prueba con roles distintos (usa
  `POST /department/assignManager` y `/department/assignEmployee` del
  backend PHP, o pide a Diana que te dé usuarios ya asignados) y verificar
  que cada uno cae en su dashboard correspondiente.
