import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:doliv_social/core/notifications_controller.dart';
import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/design/components/radio_bulletin_banner.dart';
import 'package:doliv_social/features/dashboard/director/internal_announcement_form.dart';
import 'package:doliv_social/models/broadcast_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ValueNotifier<BroadcastNotice?> notices;
  var dismissals = 0;
  var opens = 0;
  var taps = 0;

  BroadcastNotice bulletin([String id = '1']) => BroadcastNotice(
        id: id,
        title: 'Nuevo anuncio de Direcci\u00f3n',
        preview: 'Reuni\u00f3n de producci\u00f3n a las 16:00 en cabina.',
      );

  void dismiss(BroadcastNotice notice) {
    dismissals++;
    if (identical(notices.value, notice)) notices.value = null;
  }

  Widget app(
          {bool reduced = false,
          ThemeData? theme,
          double scale = 1,
          GlobalKey? boundary,
          Widget? home}) =>
      MaterialApp(
        theme: theme ?? AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
              disableAnimations: reduced, textScaler: TextScaler.linear(scale)),
          child: RepaintBoundary(
            key: boundary,
            child: RadioBulletinHost(
              notice: notices,
              onDismiss: dismiss,
              onOpen: (_) => opens++,
              child: child!,
            ),
          ),
        ),
        home: home ??
            Scaffold(
              appBar: AppBar(title: const Text('Radio Doliv')),
              body: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 210),
                      const TextField(
                          decoration:
                              InputDecoration(labelText: 'Mensaje al equipo')),
                      const SizedBox(height: 20),
                      FilledButton(
                          onPressed: () => taps++,
                          child: const Text('Continuar')),
                    ]),
              ),
            ),
      );

  setUp(() {
    dismissals = 0;
    opens = 0;
    taps = 0;
    notices = ValueNotifier(null);
  });
  tearDown(() => notices.dispose());

  testWidgets('banner leaves screen interactive and preserves keyboard focus',
      (tester) async {
    await tester.pumpWidget(app());
    final baseBarriers = find.byType(ModalBarrier).evaluate().length;
    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'Borrador');
    final focus = FocusManager.instance.primaryFocus;
    notices.value = bulletin();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(FocusManager.instance.primaryFocus, same(focus));
    await tester.tap(find.text('Continuar'));
    expect(taps, 1);
    expect(find.text('Borrador'), findsOneWidget);
    // The banner must not add its own barrier over the active screen.
    expect(find.byType(ModalBarrier).evaluate().length, baseBarriers);
    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(milliseconds: 250));
    expect(notices.value, isNull);
    expect(dismissals, 1);
  });

  testWidgets('swipe removes the notice once', (tester) async {
    await tester.pumpWidget(app());
    notices.value = bulletin();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.drag(find.byType(Dismissible), const Offset(650, 0));
    await tester.pumpAndSettle();
    expect(notices.value, isNull);
    expect(dismissals, 1);
    await tester.pump(const Duration(seconds: 8));
    expect(dismissals, 1);
  });

  testWidgets('close and tap actions dismiss without opening twice',
      (tester) async {
    await tester.pumpWidget(app());
    notices.value = bulletin();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.byTooltip('Cerrar aviso'));
    await tester.pumpAndSettle();
    expect(opens, 0);
    notices.value = bulletin('2');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text(bulletin().title));
    await tester.pump();
    expect(opens, 1);
    expect(dismissals, 2);
    expect(notices.value, isNull);
  });

  testWidgets('replacement cancels old timers and disposal is safe',
      (tester) async {
    await tester.pumpWidget(app());
    notices.value = bulletin();
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    notices.value = bulletin('2');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(seconds: 3));
    expect(notices.value!.id, '2');
    expect(dismissals, 0);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
    expect(dismissals, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion holds a static notice and still auto dismisses',
      (tester) async {
    await tester.pumpWidget(app(reduced: true));
    notices.value = bulletin();
    await tester.pump();
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(find.text('ON AIR'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    expect(notices.value, isNull);
    expect(dismissals, 1);
  });

  testWidgets('publication shows confirmation only after server success',
      (tester) async {
    final controller = NotificationsController.instance;
    controller.clear();
    addTearDown(controller.clear);
    FlutterSecureStorage.setMockInitialValues({'accessToken': 'test-session'});
    void forwardNotice() => notices.value = controller.bulletin.value;
    controller.bulletin.addListener(forwardNotice);
    addTearDown(() => controller.bulletin.removeListener(forwardNotice));
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigator,
      theme: AppTheme.light,
      builder: (context, child) => RadioBulletinHost(
        notice: notices,
        onDismiss: dismiss,
        child: child!,
      ),
      home: const Scaffold(body: Text('Tablero de anuncios')),
    ));
    unawaited(navigator.currentState!.push(MaterialPageRoute<void>(
      builder: (_) => const InternalAnnouncementFormScreen(),
    )));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextFormField).at(0), 'Reunion de produccion');
    await tester.enterText(
        find.byType(TextFormField).at(1), 'Hoy a las 16:00 en cabina.');
    await tester.dragUntilVisible(
      find.byType(AppButton),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    final response = Completer<http.Response>();
    http.runWithClient(
      tester.widget<AppButton>(find.byType(AppButton)).onPressed!,
      () => MockClient((_) => response.future),
    );
    await tester.pump();
    expect(notices.value, isNull);
    response.complete(http.Response(
        '{"announcement":{"id":"test-bulletin",'
        '"title":"Reunion de produccion","body":"Hoy a las 16:00 en cabina."}}',
        200));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(notices.value!.id, 'published:test-bulletin');
    expect(find.text('Anuncio publicado'), findsOneWidget);
    expect(find.byType(InternalAnnouncementFormScreen), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  for (final layout in [
    (name: 'mobile-dark', size: const Size(390, 844), dark: true, scale: 1.0),
    (
      name: 'desktop-light',
      size: const Size(1280, 800),
      dark: false,
      scale: 1.0
    ),
    (name: 'large-text', size: const Size(320, 640), dark: true, scale: 2.0),
  ]) {
    testWidgets('banner layout ${layout.name}', (tester) async {
      tester.view.physicalSize = layout.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var theme = layout.dark ? AppTheme.dark : AppTheme.light;
      const font = String.fromEnvironment('RADIO_PREVIEW_FONT');
      if (font.isNotEmpty) {
        await tester.runAsync(() async {
          final loader = FontLoader('BulletinPreview')
            ..addFont(File(font).readAsBytes().then(ByteData.sublistView));
          await loader.load();
          final icons = FontLoader('MaterialIcons')
            ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
          await icons.load();
        });
        theme = theme.copyWith(
            textTheme: theme.textTheme.apply(fontFamily: 'BulletinPreview'));
      }
      final boundary = GlobalKey();
      await tester.pumpWidget(
          app(theme: theme, scale: layout.scale, boundary: boundary));
      notices.value = bulletin();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(RadioBulletinBanner)).height,
          lessThan(layout.size.height / 2));
      const directory = String.fromEnvironment('BULLETIN_PREVIEW_DIR');
      if (directory.isNotEmpty) {
        await tester.runAsync(() async {
          final render = boundary.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
          final image = await render.toImage();
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory(directory).create(recursive: true);
          await File('$directory/${layout.name}.png')
              .writeAsBytes(png!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.pumpWidget(const SizedBox());
    });
  }
}
