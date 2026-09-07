import 'package:flutter_test/flutter_test.dart';
import 'package:doliv_social/core/push/push_messages.dart';

void main() {
  group('normalizePushData', () {
    test('coerces keys and values to strings, null -> empty', () {
      final out = normalizePushData(<Object?, Object?>{
        'type': 'chat',
        'entityId': 'a@b.com',
        'count': 3,
        'missing': null,
      });
      expect(out, {
        'type': 'chat',
        'entityId': 'a@b.com',
        'count': '3',
        'missing': '',
      });
    });
  });

  group('shouldShowLocalNotification', () {
    test('suppresses a chat push for the open thread', () {
      expect(
        shouldShowLocalNotification(
          {'type': 'chat', 'entityId': 'ana@doliv.test'},
          'ana@doliv.test',
        ),
        isFalse,
      );
    });

    test('shows a chat push for a different thread', () {
      expect(
        shouldShowLocalNotification(
          {'type': 'chat', 'entityId': 'ana@doliv.test'},
          'beto@doliv.test',
        ),
        isTrue,
      );
    });

    test('shows a chat push when no thread is open', () {
      expect(
        shouldShowLocalNotification(
          {'type': 'chat', 'entityId': 'ana@doliv.test'},
          null,
        ),
        isTrue,
      );
    });

    test('always shows a non-chat push', () {
      expect(
        shouldShowLocalNotification(
          {'type': 'dept_task', 'entityId': 'ana@doliv.test'},
          'ana@doliv.test',
        ),
        isTrue,
      );
    });
  });

  group('localNotificationId', () {
    test('is stable for the same type + entity', () {
      final a = localNotificationId({'type': 'chat', 'entityId': 'ana@doliv.test'});
      final b = localNotificationId({'type': 'chat', 'entityId': 'ana@doliv.test'});
      expect(a, b);
    });

    test('differs by entity', () {
      final a = localNotificationId({'type': 'chat', 'entityId': 'ana@doliv.test'});
      final b = localNotificationId({'type': 'chat', 'entityId': 'beto@doliv.test'});
      expect(a, isNot(b));
    });

    test('chat cases with a non-empty entityId ignore notifId', () {
      final a = localNotificationId(
        {'type': 'chat', 'entityId': 'ana@doliv.test', 'notifId': '1'},
      );
      final b = localNotificationId(
        {'type': 'chat', 'entityId': 'ana@doliv.test', 'notifId': '2'},
      );
      final base = localNotificationId(
        {'type': 'chat', 'entityId': 'ana@doliv.test'},
      );
      expect(a, base);
      expect(b, base);
    });

    test('empty entityId falls back to notifId so rows do not collide', () {
      final a = localNotificationId(
        {'type': 'event_created', 'entityId': '', 'notifId': '101'},
      );
      final b = localNotificationId(
        {'type': 'event_created', 'entityId': '', 'notifId': '102'},
      );
      expect(a, isNot(b));
    });

    test('is a non-negative 31-bit int', () {
      final id = localNotificationId({'type': 'x', 'entityId': 'y'});
      expect(id, greaterThanOrEqualTo(0));
      expect(id, lessThanOrEqualTo(0x7fffffff));
    });
  });
}
