# Team Management App - Radio Doliv Organizational Update

> This document describes the new architecture and functional requirements for the next version of the application.

## Overview

The current application is designed as a generic team management platform.

The project must now evolve into an organizational management system specifically designed for **Radio Doliv**, introducing a hierarchical company structure with three different access levels:

- Director General
- Department Manager
- Employee

> **IMPORTANT**
>
> Although this document is written in English, **the entire application UI must remain 100% in Spanish**, including buttons, dialogs, menus, notifications, validation messages, and all user-facing text.

---

# Estado de la implementación (plantilla de seguimiento)

> Esta tabla es la plantilla que debe usar cada equipo para reportar avance.
> Al tomar un módulo: cambiar `Estado` a `En progreso`, poner el nombre del
> equipo/persona, y actualizar a `Hecho` con un enlace al PR al terminar.
> **Recordatorio de arquitectura**: el backend que realmente sirve la app es
> **PHP en `C:\xampp\htdocs\hive-backend`** (no la carpeta `backend/` Node del
> repo, que es código muerto). Toda la BD real es `hive_db`, no lo que
> describe `database/schema.sql`.

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

# New Organizational Structure

The application should represent the following hierarchy:

```
Company (Radio Doliv)

└── Director General
      │
      ├── Marketing
      │      ├── Manager
      │      └── Employees
      │
      ├── Systems
      │      ├── Manager
      │      └── Employees
      │
      ├── Human Resources
      │      ├── Manager
      │      └── Employees
      │
      └── Broadcasting
             ├── Manager
             └── Employees
```

The concept of **Team** should gradually evolve into a company-wide organizational structure.

---

# User Roles

## Director General

Highest level of permissions.

Responsibilities:

- Create departments
- Register department managers
- Register employees
- Assign department managers
- Create company-wide announcements
- Create strategic tasks
- Assign tasks to departments
- View company analytics
- View department performance
- Approve leave requests
- Access all chats
- Access all shared resources

---

## Department Manager

Each department has exactly one manager.

Responsibilities:

- Manage department employees
- Create tasks
- Assign tasks
- Validate completed tasks
- Create department announcements
- Upload shared resources
- View department reports
- Approve employee work
- Manage department chat

Managers cannot modify other departments.

---

## Employee

Employees have limited permissions.

They can:

- View assigned tasks
- Complete tasks
- View announcements
- Access department chat
- Upload work resources
- Request leave
- View personal progress
- View department information

Employees cannot manage users.

---

# Departments

The initial departments are:

- Marketing
- Systems
- Human Resources
- Broadcasting

The architecture must allow creating additional departments in the future.

---

# Dashboard Redesign

Instead of a single dashboard, the application should display different dashboards depending on the authenticated user's role.

## Director Dashboard

Includes:

- Company overview
- Departments
- Employees
- Active tasks
- Performance charts
- Leave approvals
- Company announcements
- Reports

---

## Manager Dashboard

Includes:

- Department overview
- Department employees
- Pending tasks
- Completed tasks
- Department resources
- Department announcements
- Chat

---

## Employee Dashboard

Includes:

- My Tasks
- My Progress
- My Calendar
- My Announcements
- Department Chat
- Shared Resources
- Leave Requests

---

# Permission System

Replace the current Team Leader authorization model with a Role-Based Access Control (RBAC) system.

Supported roles:

```
director

manager

employee
```

Every endpoint should validate permissions according to the authenticated user's role.

---

# Database Changes

## Companies

Create a company entity.

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

Extend the existing users table with:

```
department_id

role

position
```

Examples:

```
Software Engineer

Marketing Specialist

Radio Host

HR Coordinator
```

---

## Tasks

Extend tasks with:

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

Create a new table.

```
announcements

id

title

content

department_id

created_by

created_at
```

If

```
department_id = NULL
```

the announcement is visible company-wide.

---

## Reports

Create a reports module.

```
reports

employee_id

manager_id

week

performance

comments
```

---

# Task Workflow

Tasks should follow this workflow:

```
Director

↓

Department

↓

Manager

↓

Employee

↓

Employee completes task

↓

Manager validates

↓

Director views statistics
```

---

# Leave Requests

Employees submit leave requests.

Managers review department requests.

The Director General has final visibility over every request.

---

# Notifications

Notifications should support:

- New task assigned
- Task completed
- Task approved
- Leave approved
- Leave rejected
- New announcement
- Department updates
- Resource uploaded

---

# Reports & Analytics

The Director dashboard should include:

- Tasks by department
- Completed tasks
- Pending tasks
- Employee productivity
- Department productivity
- Weekly statistics
- Monthly statistics

Managers should only see their own department's analytics.

---

# Chat

Keep the existing chat module.

Add support for:

- Department chat
- Company announcements
- System notifications

---

# Resources

Keep the shared resources module.

Resources belong to a department.

Supported resource types:

- Documents
- Images
- PDFs
- Videos
- External links

---

# Future Features

The architecture should be designed to support future modules without major refactoring.

Examples:

- Attendance control
- Time tracking
- Electronic signatures
- KPI dashboards
- Calendar integration
- Push notifications
- Mobile notifications
- Project management
- Performance evaluations

---

# UI Language Requirement

**This is mandatory.**

The project documentation, source code, comments, and README files may be written in Spanish.

However:

- Every screen
- Every button
- Every dialog
- Every validation
- Every notification
- Every error message
- Every menu
- Every label
- Every form

**must remain entirely in Spanish.**

No English text should appear anywhere in the user interface.

---

# Migration Notes

The current project already contains working modules for:

- Authentication
- Tasks
- Notifications
- Chat
- Shared Resources
- Leave Requests

These modules should be reused whenever possible.

The migration should focus on replacing the existing Team/Leader architecture with the new Company/Department/Role hierarchy while minimizing unnecessary refactoring.