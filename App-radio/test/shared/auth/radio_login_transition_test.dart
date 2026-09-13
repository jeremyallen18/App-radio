import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:doliv_social/core/routes.dart';
import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/shared/auth/login.dart';
import 'package:doliv_social/shared/auth/widgets/radio_login_transition.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets(
      'successful login waits for the broadcast and clears login history',
      (tester) async {
    final response = Completer<http.Response>();
    var requests = 0;
    var dashboardBuilds = 0;
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigator,
      theme: AppTheme.light,
      home: const Login(),
      routes: {
        MyRoutes.bottomNavBar: (_) {
          dashboardBuilds++;
          return const Scaffold(body: Text('Dashboard destination'));
        },
      },
    ));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextFormField).at(0), 'host@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'test-password');
    final submit = tester.widget<AppButton>(find.byType(AppButton)).onPressed!;
    http.runWithClient(() {
      submit();
      submit();
    },
        () => MockClient((request) {
              if (request.url.path.endsWith('/user/login')) {
                requests++;
                return response.future;
              }
              return Future.value(http.Response('{}', 503));
            }));
    await tester.pump();
    expect(requests, 1);
    expect(tester.widget<AppButton>(find.byType(AppButton)).loading, isTrue);
    expect(find.byType(RadioLoginTransition), findsNothing);

    response.complete(http.Response(
      '{"token":"test-session","emailVerified":true}',
      200,
    ));
    await tester.pump();
    await tester.pump();
    expect(await secureStorage.readSecureData(key), 'test-session');
    expect(find.byType(RadioLoginTransition), findsOneWidget);
    expect(dashboardBuilds, 0);
    await navigator.currentState!.maybePop();
    await tester.pump(const Duration(milliseconds: 1700));
    expect(find.byType(RadioLoginTransition), findsOneWidget);
    expect(dashboardBuilds, 0);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('Dashboard destination'), findsOneWidget);
    expect(find.byType(Login), findsNothing);
    expect(dashboardBuilds, 1);
    expect(navigator.currentState!.canPop(), isFalse);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  for (final failure in [
    (status: 401, body: '{}'),
    (status: 403, body: '{"code":"EMAIL_UNVERIFIED"}'),
    (status: 200, body: '{"token":null}'),
  ]) {
    testWidgets(
        'rejected login ${failure.status}/${failure.body} stays editable',
        (tester) async {
      await tester
          .pumpWidget(MaterialApp(theme: AppTheme.light, home: const Login()));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byType(TextFormField).at(0), 'host@example.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'test-password');
      http.runWithClient(
        tester.widget<AppButton>(find.byType(AppButton)).onPressed!,
        () => MockClient(
            (_) async => http.Response(failure.body, failure.status)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(RadioLoginTransition), findsNothing);
      expect(tester.widget<AppButton>(find.byType(AppButton)).loading, isFalse);
      expect(await secureStorage.readSecureData(key), isNull);
    });
  }

  testWidgets('reduced motion completes after one frame without waiting',
      (tester) async {
    var completions = 0;
    Widget screen() => MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: RadioLoginTransition(onCompleted: () => completions++),
          ),
        );
    await tester.pumpWidget(screen());
    expect(completions, 1);
    await tester.pumpWidget(screen());
    expect(completions, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disposal cancels navigation during tuning', (tester) async {
    var completions = 0;
    await tester.pumpWidget(MaterialApp(
      home: RadioLoginTransition(onCompleted: () => completions++),
    ));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(RadioLoginTransition.duration);
    expect(completions, 0);
    expect(tester.takeException(), isNull);
  });

  for (final layout in [
    (name: 'phone-dark', size: const Size(390, 844), dark: true, scale: 1.0),
    (
      name: 'desktop-light',
      size: const Size(1280, 800),
      dark: false,
      scale: 1.0
    ),
    (
      name: 'small-large-text',
      size: const Size(320, 568),
      dark: false,
      scale: 2.0
    ),
    (name: 'landscape', size: const Size(568, 320), dark: true, scale: 1.0),
  ]) {
    testWidgets('broadcast fits ${layout.name} and its canvas moves',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = layout.size;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final boundary = GlobalKey();
      var completions = 0;
      // Optional local previews use a real font; normal tests need no font file.
      const previewFont = String.fromEnvironment('RADIO_PREVIEW_FONT');
      if (previewFont.isNotEmpty) {
        await tester.runAsync(() async {
          final loader = FontLoader('RadioPreview')
            ..addFont(
                File(previewFont).readAsBytes().then(ByteData.sublistView));
          await loader.load();
        });
      }
      final theme = layout.dark ? AppTheme.dark : AppTheme.light;
      await tester.pumpWidget(MaterialApp(
        theme: previewFont.isEmpty
            ? theme
            : theme.copyWith(
                textTheme: theme.textTheme.apply(fontFamily: 'RadioPreview')),
        home: MediaQuery(
          data: MediaQueryData(
              size: layout.size, textScaler: TextScaler.linear(layout.scale)),
          child: RepaintBoundary(
            key: boundary,
            child: RadioLoginTransition(onCompleted: () => completions++),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 200));
      final tuning = await _capture(tester, boundary, '${layout.name}-tuning');
      await tester.pump(const Duration(milliseconds: 500));
      final searching =
          await _capture(tester, boundary, '${layout.name}-searching');
      expect(listEquals(tuning, searching), isFalse);
      await tester.pump(const Duration(milliseconds: 1000));
      final locked = await _capture(tester, boundary, '${layout.name}-locked');
      expect(listEquals(tuning, locked), isFalse);
      expect(completions, 0);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 600));
      expect(completions, 1);
      expect(tester.takeException(), isNull);
    });
  }
}

Future<Uint8List> _capture(
    WidgetTester tester, GlobalKey key, String name) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  return (await tester.runAsync(() async {
    final image = await boundary.toImage();
    try {
      final pixels = (await image.toByteData())!.buffer.asUint8List();
      const previewDirectory = String.fromEnvironment('RADIO_PREVIEW_DIR');
      if (previewDirectory.isNotEmpty) {
        await Directory(previewDirectory).create(recursive: true);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('$previewDirectory/$name.png')
            .writeAsBytes(png!.buffer.asUint8List());
      }
      return pixels;
    } finally {
      image.dispose();
    }
  }))!;
}
