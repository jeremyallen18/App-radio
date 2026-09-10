# Vinculación de dispositivo y verificación biométrica en el fichaje — diseño

Fecha: 2026-09-09
Estado: aprobado para implementación (decisiones tomadas en la sesión de
brainstorming del 2026-09-09).

## Problema

El módulo de asistencia (`hive-backend/attendance.php` + `attendance_admin.php`,
Flutter `lib/shared/attendance/*`) hoy valida al fichar:

- **Hora del servidor** (la marca oficial nunca viene del dispositivo).
- **Geocerca** en `entrada` y `fin_comida`: el GPS debe caer dentro del radio
  configurado (`attendance_location`, 10 m por defecto).
- **Ventana horaria** de entrada / comida / salida y **rol** (`employee` /
  `manager`; el director nunca ficha).

Todo eso verifica que **el teléfono está en el lugar a la hora correcta**, nunca
que **la persona titular de la cuenta es quien toca el botón**. Caso de fraude:
un empleado decide no asistir, presta su teléfono desbloqueado (o su cuenta
abierta en otro teléfono) a un compañero que está dentro de la geocerca, y ese
compañero registra la entrada. El `device_time`, `latitude`, `longitude` y
`method` que ya se guardan no permiten distinguir ese caso.

Se quiere reforzar el fichaje con verificación multifactor de presencia:
(1) sesión válida —ya existe—, (2) la cuenta vinculada a **un** dispositivo
autorizado, (3) verificación biométrica del sistema operativo antes de entrada y
salida, (4) geocerca —ya existe—, (5) registro de evidencias por evento,
(6) detección de anomalías para revisión del director.

## Decisiones (sesión de brainstorming)

| Tema | Decisión |
|------|----------|
| Identificación del dispositivo | **Enfoque B**: clave primaria `ANDROID_ID` (Android) / `identifierForVendor` (iOS), con un UUID en `flutter_secure_storage` como respaldo. En la base se guarda **solo el SHA-256** de cada identificador, nunca el valor crudo. Attestation fuerte (Play Integrity / App Attest) queda descartada por sobredimensionada para el caso. |
| Dispositivos por cuenta | **1**. Cualquier cambio pasa por el director. |
| Alta del primer dispositivo | **Trust-on-first-use**: el primer dispositivo desde el que el empleado ficha se registra solo. Se marca la evidencia como `first_use`. |
| Dispositivo no confiado (teléfono nuevo, o ya hay uno vinculado) | **Bloquear el fichaje** (`code = UNKNOWN_DEVICE`) y ofrecer en la app "Solicitar autorización de este dispositivo". El director aprueba/rechaza en su panel. Aprobar **reemplaza** el dispositivo confiado anterior (es 1 solo). |
| Biometría sin configurar / sin hardware | `local_auth.authenticate(biometricOnly: false)` → se acepta el **PIN/patrón del sistema** como respaldo (`biometric_result = 'skipped'`). Si no hay ningún bloqueo de pantalla, se bloquea el fichaje con instrucción de configurarlo. |
| Eventos que exigen biometría | **Solo `entrada` y `salida`** (enmarcan la jornada y pesan en nómina). |
| Eventos que exigen dispositivo confiado | **Todos** (`entrada`, `inicio_comida`, `fin_comida`, `salida`, `sin_comida`): la vinculación es por cuenta y se verifica en cada escritura. |
| Alcance de usuarios | **Empleados y managers** (ambos fichan su propia asistencia). El director sigue sin fichar. |
| Quién resuelve solicitudes de dispositivo | **Solo el director.** El manager **no ve** la pantalla de dispositivos. |
| Recuperación de teléfono perdido | El director puede **Restablecer** el dispositivo de un empleado; el siguiente fichaje re-vincula por *first-use*. |
| Confianza en el resultado biométrico | El backend confía en la aserción del cliente (`biometricResult`), verificada por el SO; falsearla exige manipular la app, fuera del modelo de amenaza (compañero que pide el teléfono prestado). |
| Privacidad | Solo hashes de identificadores. La app nunca accede a datos biométricos: `local_auth` solo devuelve `true/false`. RR. HH. incorpora una línea al aviso de privacidad / contrato. |

## Modelo de amenaza y límite conocido

Cubre: fichaje desde el teléfono propio de otra persona con la cuenta ajena
abierta (cae fuera del dispositivo confiado) y fichaje sin la persona presente
(la biometría lo corta en entrada/salida). **No cubre**: que el titular preste
su teléfono físico *ya confiado* con la biometría del compañero también
registrada en ese teléfono — ese caso solo lo cerraría una selfie con
verificación facial, fuera de alcance de este diseño.

## 1. Pipeline de fichaje

### 1.1 Cliente (Flutter)

Al tocar "Registrar entrada/salida/comida", **antes de cualquier llamada de red**:

1. **Biometría** (solo `entrada` y `salida`):
   `local_auth.authenticate(biometricOnly: false, options: AuthenticationOptions(stickyAuth: true))`.
   El SO pide huella/rostro y, si no hay biométrico, PIN/patrón.
   - Cancelada o fallida → se aborta sin tocar el servidor. Toast:
     "Verificación cancelada, inténtalo de nuevo".
   - `local_auth` lanza excepción por no haber ningún bloqueo de pantalla →
     "Configura un bloqueo de pantalla (huella o PIN) para poder registrar tu
     asistencia".
   - Éxito → `biometricResult = 'ok'` (biométrico real) o `'skipped'` (se usó
     credencial del dispositivo); `biometricType ∈ {fingerprint, face, device_credential}`.
2. **GPS**: como hoy para `entrada`/`fin_comida`, capturando además la precisión
   (`locationAccuracy`, metros).
3. **Identidad del dispositivo** — módulo nuevo `lib/core/device/device_identity.dart`:
   - `deviceKey` = `ANDROID_ID` (paquete `android_id`) / `identifierForVendor`
     (`device_info_plus`, iOS). Puede venir `null`.
   - `deviceUuid` = `Uuid().v4()` generado una vez y guardado en
     `flutter_secure_storage` bajo la clave `att_device_uuid`.
   - `platform`, `model`, `osVersion` (`device_info_plus`), `appVersion`
     (`package_info_plus` si ya está; si no, constante de build).
4. POST al endpoint de siempre con el body extendido (§3.1).

### 1.2 Backend (`attendance.php`)

Se intercala **un paso nuevo** entre las validaciones actuales (rol → día
laboral → ausencia → ventana horaria) y la geocerca, en un helper
`attendance_verify_device(PDO, array $user, array $body): array` que devuelve
`['status' => 'trusted'|'first_use'|'director_approved', 'device_key' => hash]`:

1. `hashKey = sha256(deviceKey)` si llega; `hashUuid = sha256(deviceUuid)` si llega.
2. `SELECT * FROM attendance_trusted_devices WHERE employee_id = ?`.
   - **Sin fila** → *trust-on-first-use*: `INSERT` con `enrolled_via = 'first_use'`.
     Devuelve `status = 'first_use'`. Si el empleado ya tenía asistencia previa
     con otro `device_key`, se registra la anomalía `first_use_after_history`
     (§4.2) — pero el fichaje **no** se bloquea.
   - **Fila coincide** (`hashKey == device_key` OR, si `deviceKey` es null,
     `hashUuid == device_uuid`) → `status = 'trusted'`
     (o `'director_approved'` si `enrolled_via = 'director'`).
   - **Fila existe y NO coincide** → `attendance_device_upsert_request()`
     (crea/actualiza `attendance_device_requests`: `status='pending'`,
     `attempts+1`, `last_seen=now`) y corta con
     `json_response(['success'=>false,'code'=>'UNKNOWN_DEVICE','message'=>
     'Este dispositivo no está autorizado para registrar tu asistencia.
     Solicita al director que lo autorice.'], 409)`.
3. Para `entrada`/`salida`: si `body['biometricResult'] === 'failed'` o falta →
   corta con `code = 'BIOMETRIC_REQUIRED'`, mensaje "Debes completar la
   verificación de tu dispositivo para registrar la asistencia."

El resultado (`device_key`, `device_status`, `biometric_result`,
`biometric_type`, `location_accuracy_m`) se pasa a `attendance_insert_event()`
para guardarse como evidencia inmutable.

### 1.3 Estado del dispositivo para la UI

`POST /attendance/device/status` responde `state ∈ {trusted, none, pending, unknown}`
para que la app pinte el botón antes de que el trabajador toque fichar:
- `trusted` → botón normal.
- `none` → botón normal + nota "Este dispositivo se vinculará a tu cuenta al fichar".
- `pending` → botón deshabilitado, "Esperando que el director autorice este dispositivo".
- `unknown` → botón "Solicitar autorización del dispositivo" → `POST /attendance/device/request`.

## 2. Base de datos — migración `033_attendance_device_binding.sql`

```sql
USE hive_db;

CREATE TABLE IF NOT EXISTS attendance_trusted_devices (
  employee_id CHAR(24) NOT NULL PRIMARY KEY,   -- 1 dispositivo por cuenta
  device_key   VARCHAR(64) NOT NULL,           -- sha256(ANDROID_ID | IDFV)
  device_uuid  VARCHAR(64) NULL,               -- sha256(uuid de secure storage)
  platform     ENUM('android','ios') NOT NULL,
  model        VARCHAR(120) NULL,
  os_version   VARCHAR(60) NULL,
  app_version  VARCHAR(30) NULL,
  enrolled_at  DATETIME NOT NULL,
  enrolled_via ENUM('first_use','director') NOT NULL DEFAULT 'first_use',
  approved_by  CHAR(24) NULL,
  FOREIGN KEY (employee_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (approved_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS attendance_device_requests (
  id INT AUTO_INCREMENT PRIMARY KEY,
  employee_id CHAR(24) NOT NULL,
  device_key   VARCHAR(64) NOT NULL,
  device_uuid  VARCHAR(64) NULL,
  platform     ENUM('android','ios') NOT NULL,
  model        VARCHAR(120) NULL,
  os_version   VARCHAR(60) NULL,
  app_version  VARCHAR(30) NULL,
  status       ENUM('pending','approved','rejected') NOT NULL DEFAULT 'pending',
  attempts     INT NOT NULL DEFAULT 1,
  first_seen   DATETIME NOT NULL,
  last_seen    DATETIME NOT NULL,
  resolved_by  CHAR(24) NULL,
  resolved_at  DATETIME NULL,
  note         VARCHAR(255) NULL,
  UNIQUE KEY uq_att_dev_req (employee_id, device_key),
  KEY idx_att_dev_req_status (status),
  FOREIGN KEY (employee_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (resolved_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB;

ALTER TABLE attendance
  ADD COLUMN location_accuracy_m DECIMAL(6,1) NULL AFTER longitude,
  ADD COLUMN device_key    VARCHAR(64) NULL AFTER method,
  ADD COLUMN device_status ENUM('trusted','first_use','director_approved') NULL AFTER device_key,
  ADD COLUMN biometric_result ENUM('ok','skipped','failed') NULL AFTER device_status,
  ADD COLUMN biometric_type   VARCHAR(20) NULL AFTER biometric_result;
```

- `schema.sql` se actualiza a mano en paralelo (patrón del repo).
- Filas de `attendance` previas quedan con las columnas nuevas en `NULL`
  (evidencia no disponible para el histórico anterior a esta función).
- Interacción con la migración 027 (cifrado en reposo): los hashes no requieren
  cifrado; `model` / `os_version` son de baja sensibilidad. Se confirma al
  implementar que no rompe el patrón de columnas cifradas existente.

## 3. Endpoints

### 3.1 Del trabajador (`attendance.php`)

- `POST /attendance/entry | /attendance/meal/start | /attendance/meal/skip | /attendance/meal/end | /attendance/exit`
  — **body extendido**: `deviceKey?`, `deviceUuid?`, `platform`, `model?`,
  `osVersion?`, `appVersion?`, `biometricResult?` (`ok|skipped|failed`),
  `biometricType?`, `locationAccuracy?`. Nuevos códigos de error:
  `UNKNOWN_DEVICE` (409), `BIOMETRIC_REQUIRED` (409).
- `POST /attendance/device/status` (los identificadores van en el cuerpo, no en la
  query string) → `{ state: trusted|none|pending|unknown, device?: {model, osVersion, enrolledAt, via} }`.
- `POST /attendance/device/request` — alta explícita del dispositivo actual
  bloqueado; crea/actualiza `attendance_device_requests` a `pending`. Idempotente.

### 3.2 Del director (`attendance_admin.php`, patrón `canEdit` = solo director)

- `GET /admin/attendance/device-requests?status=pending` →
  `{ requests: [{ id, employee:{id,name}, platform, model, osVersion, attempts, firstSeen, lastSeen }] }`.
- `POST /admin/attendance/device-requests/{id}/resolve` — `{ decision: approve|reject, note? }`.
  `approve` → `REPLACE INTO attendance_trusted_devices` con los datos de la
  solicitud, `enrolled_via='director'`, `approved_by = director.id`; marca la
  solicitud `approved`. `reject` → solicitud `rejected` + `note`.
- `GET /admin/attendance/{employeeId}/device` → dispositivo confiado actual o `null`.
- `POST /admin/attendance/{employeeId}/device/reset` — `DELETE` de la fila de
  `attendance_trusted_devices`; el próximo fichaje re-vincula por *first-use*.
  Deja traza en el log de auditoría existente si lo hay.
- Todos exigen rol `director`; el manager recibe 403.

### 3.3 Cliente (`lib/services/attendance_service.dart`)

- `AttendanceApi.perform(...)` gana parámetros `deviceKey`, `deviceUuid`,
  `platform`, `model`, `osVersion`, `appVersion`, `biometricResult`,
  `biometricType`, `locationAccuracy`.
- Métodos nuevos: `deviceStatus()`, `requestDevice()`; y admin
  `deviceRequests({status})`, `resolveDeviceRequest(id, {approve, note})`,
  `employeeDevice(employeeId)`, `resetEmployeeDevice(employeeId)`.
- Mismo patrón de transporte y extracción de `message`/`code` que el resto del
  archivo. `AttendanceException.code` ya soporta los códigos nuevos.

## 4. Panel del director

### 4.1 Pantalla nueva "Dispositivos de asistencia"

Accesible desde el dashboard del director junto a "Horarios" y "Lugar de
asistencia" (patrón `features/dashboard/director/admin_schedule_screen.dart` /
`admin_location_screen.dart`). **No visible para el manager.** Contiene:

**Solicitudes pendientes** — tarjeta por solicitud: empleado, modelo + SO,
nº de intentos, primera y última vez. Botones **Aprobar** / **Rechazar**
(con nota opcional). Aprobar muestra confirmación:
*"Esto reemplazará el dispositivo actual de [empleado] ([modelo anterior]).
Solo podrá fichar desde el nuevo."* Badge con el conteo de pendientes en el
tile del dashboard.

**Dispositivos confiados** — lista: empleado → modelo / SO / fecha de alta /
vía (`first_use` | `director`). Acción **Restablecer** (con confirmación).

**Anomalías** — lista de las señales de §4.2, cada una con enlace al empleado y
al día.

### 4.2 Detección de anomalías (reglas en backend, sin ML)

Se calculan al vuelo (endpoint `GET /admin/attendance/device-anomalies?days=30`)
y se muestran en la pantalla + badge en el dashboard. Ninguna bloquea
automáticamente; la única regla que corta el fichaje es la de dispositivo único
del pipeline (§1.2).

| Señal | Cuándo |
|------|--------|
| `unknown_device_attempt` | Existe una fila `pending`/`rejected` en `attendance_device_requests` con `last_seen` dentro del rango. |
| `first_use_after_history` | El *trust-on-first-use* se activó para un empleado con asistencia previa registrada con un `device_key` distinto. |
| `frequent_device_change` | Más de 1 `attendance_device_requests.status='approved'` para el mismo empleado en 30 días. |
| `biometric_skipped_streak` | `biometric_result='skipped'` en ≥ 3 días laborales consecutivos. Informativo, prioridad baja. |

### 4.3 Marca en la vista de asistencia existente

En `features/dashboard/director/attendance_report_screen.dart` /
`shared/attendance/admin_attendance_screen.dart`, un ícono discreto en la fila
del día cuando ese día hubo `device_status='first_use'` tras un dispositivo
distinto, o intentos `UNKNOWN_DEVICE`.

## 5. Manejo de errores (app)

| Situación | Comportamiento |
|-----------|----------------|
| Biometría cancelada / fallida | Se aborta antes de la red. Toast "Verificación cancelada, inténtalo de nuevo". |
| Sin biometría **y** sin bloqueo de pantalla | `local_auth` lanza excepción → fichaje bloqueado: "Configura un bloqueo de pantalla (huella o PIN) para poder registrar tu asistencia". |
| `deviceKey` nulo (plugin falla) | Se envía solo `deviceUuid`; el servidor empareja por UUID. |
| `device_status = pending` | Botón de fichar deshabilitado con el mensaje de espera. |
| `device_status = unknown` | Botón "Solicitar autorización del dispositivo". |
| Offline | Igual que hoy: el fichaje falla con el error de conexión existente (toda la validación es server-side). |

## 6. Privacidad / legal

- Solo SHA-256 de `ANDROID_ID` / `IDFV` / UUID en la base; nunca el valor crudo.
- La app nunca recibe datos biométricos: `local_auth` devuelve solo `true/false`.
  Se guarda `biometric_result` y `biometric_type`, nada más.
- **Aviso de privacidad / contrato** (a cargo de RR. HH.): *"Para garantizar la
  integridad del registro de asistencia, la cuenta se vincula a un dispositivo y
  se solicita la verificación del sistema operativo (biometría o código). La
  empresa no accede a datos biométricos."*
- **Retención**: filas de `attendance_device_requests` resueltas
  (`approved`/`rejected`) se purgan a los 180 días vía cron
  (`hive-backend/cron_cleanup_device_requests.php`, patrón de
  `hive-backend/cron_cleanup_unverified.php`; programarlo una vez al día). La fila de
  `attendance_trusted_devices` vive mientras el empleado esté activo
  (`ON DELETE CASCADE`). Las columnas de evidencia en `attendance` siguen la
  retención de la asistencia.

## 7. Pruebas

**Backend (PHP, patrón `hive-backend/scratchpad/` + `test/`):**
- Alta por *first-use* cuando no hay dispositivo confiado.
- Fichaje con dispositivo que coincide por `device_key` y por `device_uuid` (fallback).
- Dispositivo que no coincide → `UNKNOWN_DEVICE` + fila `pending`; reintento sube
  `attempts` y `last_seen`, no duplica (respeta `uq_att_dev_req`).
- Director aprueba → `attendance_trusted_devices` reemplazado, solicitud `approved`.
- Director rechaza → solicitud `rejected` con nota; el fichaje sigue bloqueado.
- Director restablece → siguiente fichaje re-vincula por *first-use*.
- `biometric_result='failed'` en entrada/salida → `BIOMETRIC_REQUIRED`;
  en comida no se exige biometría.
- Columnas de evidencia (`device_key`, `device_status`, `biometric_*`,
  `location_accuracy_m`) persistidas en el evento.
- Anomalía `first_use_after_history` cuando hay historial con otro `device_key`.
- Manager recibe 403 en todos los endpoints `/admin/attendance/device*`.

**Flutter:**
- `DeviceIdentity` con platform channels mockeados (Android / iOS / ambos null).
- Widget test de los 4 estados del botón (`trusted` / `none` / `pending` / `unknown`).
- Ruta de biometría cancelada → no se realiza llamada de red.

**Manual:** dos teléfonos físicos, una sola cuenta (fichar, prestar, solicitar,
aprobar, restablecer).

## 8. Fuera de alcance

- Selfie / verificación facial contra foto de referencia.
- Más de un dispositivo confiado por cuenta.
- Attestation criptográfica (Play Integrity / App Attest / DeviceCheck).
- Aprobación de dispositivos por el manager.
- Bloqueo automático por anomalías distintas a la regla de dispositivo único.
