import 'dart:async';
import 'dart:convert';

import 'package:doliv_social/core/notifications_controller.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final controller = NotificationsController.instance;

  setUp(() {
    controller.clear();
    FlutterSecureStorage.setMockInitialValues({'accessToken': 'test-session'});
  });
  tearDown(controller.clear);

  Map<String, Object?> notice(int id,
          {String type = 'internal_announcement'}) =>
      {
        'id': id,
        'type': type,
        'message': 'Announcement $id',
        'readAt': null,
      };
  Map<String, String> push(int id) => {
        'notifId': '$id',
        'type': 'internal_announcement',
        'title': 'Director',
        'body': 'Announcement $id',
      };
  Future<void> refresh(List<Map<String, Object?>> items) => http.runWithClient(
        () => controller.refresh(force: true),
        () => MockClient((_) async => http.Response(
            jsonEncode({
              'unreadCount': items.length,
              'notifications': items,
            }),
            200)),
      );

  test('initial history is silent; only newest incoming bulletin appears',
      () async {
    await refresh([notice(1)]);
    expect(controller.bulletin.value, isNull);
    await refresh([notice(3), notice(2), notice(1)]);
    expect(controller.bulletin.value!.id, '3');
    expect(controller.unreadCount, 3);
    controller.dismissBulletin(controller.bulletin.value!);
    await refresh([notice(3), notice(2), notice(1)]);
    expect(controller.bulletin.value, isNull);
  });

  test('push then polling produces one notice, including after dismissal',
      () async {
    controller.receiveAnnouncement(push(1), token: 'test-session');
    final original = controller.bulletin.value!;
    await refresh([notice(1)]);
    expect(controller.bulletin.value, same(original));
    controller.dismissBulletin(original);
    controller.receiveAnnouncement(push(1), token: 'test-session');
    expect(controller.bulletin.value, isNull);
  });

  test('polling then push does not repeat an incoming bulletin', () async {
    await refresh([]);
    await refresh([notice(1)]);
    final original = controller.bulletin.value!;
    controller.receiveAnnouncement(push(1), token: 'test-session');
    expect(controller.bulletin.value, same(original));
  });

  test('other types and reminders do not become publication bulletins',
      () async {
    await refresh([]);
    await refresh([
      notice(3, type: 'chat'),
      notice(2, type: 'internal_announcement_reminder')
    ]);
    controller.receiveAnnouncement({'notifId': '4', 'type': 'chat'},
        token: 'test-session');
    expect(controller.bulletin.value, isNull);
  });

  test('late dismissal cannot remove a replacement, logout clears all notices',
      () {
    controller.receiveAnnouncement(push(1), token: 'test-session');
    final previous = controller.bulletin.value!;
    controller.receiveAnnouncement(push(2), token: 'test-session');
    controller.dismissBulletin(previous);
    expect(controller.bulletin.value!.id, '2');
    controller.clear();
    expect(controller.bulletin.value, isNull);
    expect(controller.unreadCount, 0);
  });

  test('a response from before logout cannot restore private content',
      () async {
    final response = Completer<http.Response>();
    final started = Completer<void>();
    final request = http.runWithClient(
      () => controller.refresh(force: true),
      () => MockClient((_) {
        started.complete();
        return response.future;
      }),
    );
    await started.future;
    controller.clear();
    response.complete(http.Response(
        jsonEncode({
          'unreadCount': 1,
          'notifications': [notice(1)],
        }),
        200));
    await request;
    expect(controller.bulletin.value, isNull);
    expect(controller.unreadCount, 0);
  });
}
