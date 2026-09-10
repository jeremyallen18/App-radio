# Team Management App - Actualización Organizacional de Radio Doliv

> Este documento describe la nueva arquitectura y los requisitos funcionales para la próxima versión de la aplicación.

## Resumen

La aplicación actual está diseñada como una plataforma genérica de gestión de equipos.

El proyecto ahora debe evolucionar hacia un sistema de gestión organizacional diseñado específicamente para **Radio Doliv**, introduciendo una estructura jerárquica de empresa con tres niveles de acceso distintos:

- Director General
- Manager de Departamento
- Empleado

> **IMPORTANTE**
>
> Toda la interfaz de la aplicación debe permanecer 100% en español, incluyendo botones, diálogos, menús, notificaciones, mensajes de validación y todo el texto visible para el usuario.

---

# Estado de la implementación (plantilla de seguimiento)

> Esta tabla es la plantilla que debe usar cada equipo para reportar avance.
> Al tomar un módulo: cambiar `Estado` a `En progreso`, poner el nombre del
> equipo/persona, y actualizar a `Hecho` con un enlace al PR al terminar.
> **Recordatorio de arquitectura**: el backend que realmente sirve la app es
> **PHP en [`hive-backend/`](hive-backend/)**, dentro de este repo (servido
> localmente vía la junction `C:\xampp\htdocs\hive-backend`). Toda la BD real
> es `hive_db`.

| Módulo | Estado | Equipo | Notas |
|---|---|---|---|
| Base organizacional (companies, departments, roles, RBAC) | **Hecho** | — | Ver detalle abajo. Desbloquea todo lo demás. |
| Dashboards por rol (Director / Manager / Employee) | Pendiente | abraham | Ver [actualizaciones/abraham.md](actualizaciones/abraham.md). |
| Gestión de departamentos (UI) + Reportes y analítica | Pendiente | diana | Ver [actualizaciones/diana.md](actualizaciones/diana.md). |
| Anuncios (announcements) | Pendiente | jona | Ver [actualizaciones/jona.md](actualizaciones/jona.md). |
| Extensión de tareas (workflow Director→Manager→Employee) + Notificaciones nuevas | Pendiente | robert | Ver [actualizaciones/robert.md](actualizaciones/robert.md). |
| Leave requests jerárquico + Chat y Recursos por departamento | Pendiente | wen | Ver [actualizaciones/wen.md](actualizaciones/wen.md). |

Cada rama del repo (`abraham`, `diana`, `jona`, `robert`, `wen`) tiene su
archivo de tareas correspondiente en [actualizaciones/](actualizaciones/README.md).

## Base organizacional — qué quedó hecho

**Backend PHP** (`C:\xampp\htdocs\hive-backend`):
- Migración aplicada a `hive_db`: tablas `companies` y `departments`, y
  `users` extendida con `role` (`director`/`manager`/`employee`, default
  `employee`), `position`, `department_id` (ver
  `hive-backend/schema.sql` y `hive-backend/migrations/001_org_structure.sql`).
- `helpers.php`: `require_role()` y `require_department_manager_or_director()`
  para proteger endpoints por rol.
- Endpoints nuevos en `index.php`:
  - `GET /user/me` — perfil del usuario autenticado (rol, position, departamento).
  - `POST /company/create`, `GET /company/info`, `POST /company/update`.
  - `POST /department/create`, `GET /department/list`.
  - `POST /department/assignManager/{id}` (solo director).
  - `POST /department/assignEmployee/{id}` (director o manager del propio departamento).
- Verificado con `node tools/php-backend-test-org.js` (28/28 pass) y sin
  regresiones en la suite existente `node tools/php-backend-test.js` (89/89 pass).

**Flutter**:
- `lib/models/models.dart`: `AppRole`, `DepartmentInfo`, `UserProfile`.
- `lib/utils/session.dart`: `Session.fetchCurrentUser()` (llama a `/user/me`
  y cachea el rol) y `Session.getCachedRole()`.
- `lib/screens/login.dart`: tras iniciar sesión, cachea el rol en segundo
  plano sin bloquear la navegación existente.

**Lo que falta a propósito** (queda para el módulo "Dashboards por rol"):
enrutar a 3 pantallas distintas según `Session.getCachedRole()`, y las
pantallas de gestión de departamentos para el Director. Ningún flujo de
equipos/tareas/chat/recursos existente fue modificado.

---

# Nueva estructura organizacional

La aplicación debe representar la siguiente jerarquía:

```
Empresa (Radio Doliv)

└── Director General
      │
      ├── Marketing
      │      ├── Manager
      │      └── Empleados
      │
      ├── Sistemas
      │      ├── Manager
      │      └── Empleados
      │
      ├── Recursos Humanos
      │      ├── Manager
      │      └── Empleados
      │
      └── Radiodifusión
             ├── Manager
             └── Empleados
```

El concepto de **Equipo** debe evolucionar gradualmente hacia una estructura organizacional a nivel de toda la empresa.

---

# Roles de usuario

## Director General

Máximo nivel de permisos.

Responsabilidades:

- Crear departamentos
- Registrar managers de departamento
- Registrar empleados
- Asignar managers de departamento
- Crear anuncios para toda la empresa
- Crear tareas estratégicas
- Asignar tareas a departamentos
- Ver analítica de la empresa
- Ver el desempeño de los departamentos
- Aprobar solicitudes de permiso
- Acceder a todos los chats
- Acceder a todos los recursos compartidos

---

## Manager de Departamento

Cada departamento tiene exactamente un manager.

Responsabilidades:

- Gestionar a los empleados del departamento
- Crear tareas
- Asignar tareas
- Validar tareas completadas
- Crear anuncios del departamento
- Subir recursos compartidos
- Ver reportes del departamento
- Aprobar el trabajo de los empleados
- Gestionar el chat del departamento

Los managers no pueden modificar otros departamentos.

---

## Empleado

Los empleados tienen permisos limitados.

Pueden:

- Ver las tareas asignadas
- Completar tareas
- Ver anuncios
- Acceder al chat del departamento
- Subir recursos de trabajo
- Solicitar permisos
- Ver su progreso personal
- Ver información del departamento

Los empleados no pueden gestionar usuarios.

---

# Departamentos

Los departamentos iniciales son:

- Marketing
- Sistemas
- Recursos Humanos
- Radiodifusión

La arquitectura debe permitir crear departamentos adicionales en el futuro.

---

# Rediseño del Dashboard

En lugar de un único dashboard, la aplicación debe mostrar dashboards distintos según el rol del usuario autenticado.

## Dashboard del Director

Incluye:

- Resumen de la empresa
- Departamentos
- Empleados
- Tareas activas
- Gráficas de desempeño
- Aprobaciones de permisos
- Anuncios de la empresa
- Reportes

---

## Dashboard del Manager

Incluye:

- Resumen del departamento
- Empleados del departamento
- Tareas pendientes
- Tareas completadas
- Recursos del departamento
- Anuncios del departamento
- Chat

---

## Dashboard del Empleado

Incluye:

- Mis Tareas
- Mi Progreso
- Mi Calendario
- Mis Anuncios
- Chat del Departamento
- Recursos Compartidos
- Solicitudes de Permiso

---

# Sistema de permisos

Reemplazar el modelo actual de autorización por Líder de Equipo con un sistema de Control de Acceso Basado en Roles (RBAC).

Roles soportados:

```
director

manager

employee
```

Todo endpoint debe validar los permisos según el rol del usuario autenticado.

---

# Cambios en la base de datos

## Companies

Crear una entidad de empresa.

```
companies

id
name
description
logo
```

---

## Departments

```
departments

id
company_id
name
description
manager_id
```

---

## Users

Extender la tabla de usuarios existente con:

```
department_id

role

position
```

Ejemplos:

```
Ingeniero de Software

Especialista en Marketing

Locutor de Radio

Coordinador de RRHH
```

---

## Tasks

Extender las tareas con:

```
created_by

assigned_by

assigned_to

department_id

priority

progress

status
```

---

## Announcements

Crear una tabla nueva.

```
announcements

id

title

content

department_id

created_by

created_at
```

Si

```
department_id = NULL
```

el anuncio es visible para toda la empresa.

---

## Reports

Crear un módulo de reportes.

```
reports

employee_id

manager_id

week

performance

comments
```

---

# Flujo de trabajo de tareas

Las tareas deben seguir este flujo:

```
Director

↓

Departamento

↓

Manager

↓

Empleado

↓

El empleado completa la tarea

↓

El manager valida

↓

El director ve las estadísticas
```

---

# Solicitudes de permiso

Los empleados envían solicitudes de permiso.

Los managers revisan las solicitudes del departamento.

El Director General tiene visibilidad final sobre todas las solicitudes.

---

# Notificaciones

Las notificaciones deben soportar:

- Nueva tarea asignada
- Tarea completada
- Tarea aprobada
- Permiso aprobado
- Permiso rechazado
- Nuevo anuncio
- Actualizaciones del departamento
- Recurso subido

---

# Reportes y Analítica

El dashboard del Director debe incluir:

- Tareas por departamento
- Tareas completadas
- Tareas pendientes
- Productividad de empleados
- Productividad por departamento
- Estadísticas semanales
- Estadísticas mensuales

Los managers solo deben ver la analítica de su propio departamento.

---

# Chat

Mantener el módulo de chat existente.

Agregar soporte para:

- Chat de departamento
- Anuncios de la empresa
- Notificaciones del sistema

---

# Recursos

Mantener el módulo de recursos compartidos existente.

Los recursos pertenecen a un departamento.

Tipos de recurso soportados:

- Documentos
- Imágenes
- PDFs
- Videos
- Enlaces externos

---

# Funcionalidades futuras

La arquitectura debe estar diseñada para soportar módulos futuros sin necesidad de una refactorización mayor.

Ejemplos:

- Control de asistencia
- Registro de horas
- Firmas electrónicas
- Dashboards de KPIs
- Integración de calendario
- Notificaciones push
- Notificaciones móviles
- Gestión de proyectos
- Evaluaciones de desempeño

---

# Requisito de idioma de la interfaz

**Esto es obligatorio.**

La documentación del proyecto, el código fuente, los comentarios y los archivos README pueden estar en español.

Sin embargo:

- Cada pantalla
- Cada botón
- Cada diálogo
- Cada validación
- Cada notificación
- Cada mensaje de error
- Cada menú
- Cada etiqueta
- Cada formulario

**debe permanecer completamente en español.**

Ningún texto en inglés debe aparecer en ninguna parte de la interfaz de usuario.

---

# Notas de migración

El proyecto actual ya contiene módulos funcionales para:

- Autenticación
- Tareas
- Notificaciones
- Chat
- Recursos Compartidos
- Solicitudes de Permiso

Estos módulos deben reutilizarse siempre que sea posible.

La migración debe enfocarse en reemplazar la arquitectura actual de Equipo/Líder por la nueva jerarquía de Empresa/Departamento/Rol, minimizando refactorizaciones innecesarias.
