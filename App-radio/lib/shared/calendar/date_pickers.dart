import 'package:flutter/material.dart';

/// Selectores de fecha compartidos para toda la app.
///
/// Reglas de negocio comunes a TODOS los calendarios de Radio Doliv:
///  - La semana laboral va de lunes a sábado.
///  - El domingo NO es laboral: no debe poder elegirse en un calendario que
///    representa una acción de trabajo (permiso, evento, entrega de tarea,
///    corrección de asistencia, anuncio…).
///  - Los textos salen en español (lo aporta `GlobalMaterialLocalizations`
///    configurado en `main.dart`; aquí solo se fija el `helpText`).
///
/// Usar estos wrappers en vez de `showDatePicker` / `showDateRangePicker`
/// directamente para que la regla del domingo se aplique en un solo lugar.

/// `true` si [day] es un día laboral (lunes a sábado).
bool isWorkingDay(DateTime day) => day.weekday != DateTime.sunday;

/// Fecha sin hora (medianoche local), para comparar solo el día.
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Última fecha permitida para un rango de "un mes de calendario" que empieza
/// en [start]: el mismo día del mes siguiente y, si ese día no existe
/// (31-ene -> "31-feb"), el último día del mes siguiente. Debe coincidir con
/// `one_calendar_month_max_end()` del backend (helpers.php).
DateTime oneCalendarMonthMaxEnd(DateTime start) {
  final s = dateOnly(start);
  final nextMonth = s.month == 12 ? 1 : s.month + 1;
  final nextYear = s.month == 12 ? s.year + 1 : s.year;
  final lastDayNextMonth = DateTime(nextYear, nextMonth + 1, 0).day;
  final day = s.day <= lastDayNextMonth ? s.day : lastDayNextMonth;
  return DateTime(nextYear, nextMonth, day);
}

/// Días de fin de semana para `TableCalendar` (solo el domingo).
const List<int> kWorkingWeekendDays = <int>[DateTime.sunday];

/// Predicado de día habilitado para `TableCalendar` (`enabledDayPredicate`).
bool tableCalendarWorkingDay(DateTime day) => isWorkingDay(day);

/// Locale de `table_calendar` (usa el formato de `intl`, ya inicializado
/// para español en `main.dart`).
const String kCalendarLocale = 'es_MX';

/// `showDatePicker` con el domingo deshabilitado y en español.
///
/// [extraSelectable] permite añadir una restricción adicional propia de la
/// pantalla (p. ej. "no futuro"): la fecha es elegible solo si es día
/// laboral Y pasa ese predicado.
Future<DateTime?> pickWorkingDate(
  BuildContext context, {
  DateTime? initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String? helpText,
  bool Function(DateTime day)? extraSelectable,
}) {
  // `initialDate` no puede caer en un día deshabilitado ni fuera de rango, o
  // `showDatePicker` lanza una aserción (debug) / abre en un día tachado.
  DateTime clamp(DateTime d) {
    if (d.isBefore(firstDate)) return firstDate;
    if (d.isAfter(lastDate)) return lastDate;
    return d;
  }

  bool selectable(DateTime d) =>
      isWorkingDay(d) && (extraSelectable == null || extraSelectable(d));

  final DateTime start = clamp(dateOnly(initialDate ?? DateTime.now()));
  DateTime seed = start;
  if (!selectable(seed)) {
    // Día elegible más cercano dentro del rango: primero hacia adelante (p. ej.
    // domingo -> lunes), y si no queda hueco por delante —lastDate es hoy y hoy
    // es domingo— hacia atrás (domingo -> sábado).
    DateTime? found;
    for (var d = start;
        !d.isAfter(lastDate);
        d = d.add(const Duration(days: 1))) {
      if (selectable(d)) {
        found = d;
        break;
      }
    }
    if (found == null) {
      for (var d = start;
          !d.isBefore(firstDate);
          d = d.subtract(const Duration(days: 1))) {
        if (selectable(d)) {
          found = d;
          break;
        }
      }
    }
    // Si no hay NINGÚN día elegible en el rango (rango degenerado del caller),
    // deja el seed dentro de rango; showDatePicker lo rechazará igualmente.
    seed = found ?? start;
  }

  return showDatePicker(
    context: context,
    initialDate: seed,
    firstDate: firstDate,
    lastDate: lastDate,
    helpText: helpText,
    selectableDayPredicate: selectable,
  );
}

/// `showDateRangePicker` en español. El picker de rango de Material no admite
/// deshabilitar días sueltos, así que el domingo no se puede "tachar" dentro
/// del calendario; en su lugar, si el inicio o el fin caen en domingo se
/// ajustan al día laboral más cercano hacia dentro del rango.
Future<DateTimeRange?> pickWorkingDateRange(
  BuildContext context, {
  DateTimeRange? initialDateRange,
  required DateTime firstDate,
  required DateTime lastDate,
  String? helpText,
  String? saveText,
}) async {
  final picked = await showDateRangePicker(
    context: context,
    initialDateRange: initialDateRange,
    firstDate: firstDate,
    lastDate: lastDate,
    helpText: helpText,
    saveText: saveText,
  );
  if (picked == null) return null;

  DateTime start = picked.start;
  DateTime end = picked.end;
  // Domingo de inicio -> lunes; domingo de fin -> sábado.
  if (!isWorkingDay(start)) {
    start = start.add(const Duration(days: 1));
  }
  if (!isWorkingDay(end)) {
    end = end.subtract(const Duration(days: 1));
  }
  if (end.isBefore(start)) end = start;
  return DateTimeRange(start: start, end: end);
}
