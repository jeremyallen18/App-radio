import 'package:flutter_test/flutter_test.dart';
import 'package:doliv_social/models/attendance.dart';

void main() {
  group('EmployeeSchedule.lateToleranceMinutes', () {
    test('toma el valor del JSON', () {
      final s = EmployeeSchedule.fromJson({
        'entryTime': '09:00',
        'exitTime': '17:00',
        'mealTime': '14:00',
        'mealMaxMinutes': 60,
        'lateToleranceMinutes': 25,
      });
      expect(s.lateToleranceMinutes, 25);
    });

    test('default 15 cuando falta la clave', () {
      final s = EmployeeSchedule.fromJson({
        'entryTime': '09:00',
        'exitTime': '17:00',
        'mealTime': '14:00',
        'mealMaxMinutes': 60,
      });
      expect(s.lateToleranceMinutes, 15);
    });
  });

  test('AttendanceDay.toleranceMinutes es null-safe', () {
    final d = AttendanceDay.fromJson({'state': 'sin_entrada'});
    expect(d.toleranceMinutes, isNull);
    final d2 = AttendanceDay.fromJson({'state': 'en_jornada', 'toleranceMinutes': 15});
    expect(d2.toleranceMinutes, 15);
  });
}
