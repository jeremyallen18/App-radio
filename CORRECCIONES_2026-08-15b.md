# Correcciones 2026-08-15 (b)

## "Gestionar tareas": que todo lo que se haga ahí se refleje en el resto de la app

**Problema:** al reasignar, reprogramar o completar una tarea desde el menú
"Gestionar tareas" (en el detalle de equipo), el backend sí guardaba el
cambio correctamente, y la propia pantalla de detalle de equipo (el panel
del líder/admin) lo mostraba al instante. Pero:

- La persona a la que se le reasignó la tarea no la veía en "Mis tareas"
  hasta que hacía swipe-to-refresh manual o reiniciaba la app — esa pantalla
  solo cargaba los datos una vez, al entrar.
- La pestaña "Tablero" (lista de equipos con conteo de pendientes/hechas)
  tampoco se actualizaba al volver del detalle de un equipo.

**Solución:** se aplicó el mismo patrón de refresco periódico que ya usaba
`teamDetail.dart` (poll cada 5 segundos, sin interrumpir el scroll ni volver
a mostrar el spinner de carga) en:

- `lib/home_page/tasks.dart` ("Mis tareas"): ahora refresca en segundo plano
  cada 5 s, así que si el líder reasigna una tarea, aparece automáticamente
  en las tareas de la persona asignada (y desaparece de las de quien la
  tenía antes).
- `lib/screens/dashboard.dart` ("Tablero"): refresca en segundo plano cada
  5 s, y además se refresca de inmediato al volver de ver el detalle de un
  equipo, para que los conteos de pendientes/hechas por equipo estén al día.

No se tocó la lógica de negocio del backend (`hive-backend/index.php`), que
ya persistía y filtraba correctamente por usuario/líder.
