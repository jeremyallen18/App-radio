import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

import 'package:doliv_social/core/api_config.dart';
import 'package:doliv_social/core/notifications_controller.dart';
import 'package:doliv_social/core/push/push_messages.dart';
import 'package:doliv_social/core/session_keys.dart' show secureStorage, key;
import 'package:doliv_social/firebase_options.dart';
import 'package:doliv_social/shared/notifications/notification_router.dart';

/// Navigator global: enruta un push tocado cuando no hay BuildContext a mano
/// (app abierta desde frío).
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

const AndroidNotificationChannel _channel = AndroidNotificationChannel(
  'doliv_default',
  'Notificaciones',
  description: 'Mensajes, tareas y avisos de Radio Doliv',
  importance: Importance.high,
);

final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

/// `Firebase.initializeApp` es un error si se llama dos veces con la app por
/// defecto; este guard lo hace idempotente (main + background handler + init).
Future<void> ensureFirebaseInitialized() async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
}

/// Handler de segundo plano / app cerrada. DEBE ser top-level y estar anotado.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await ensureFirebaseInitialized();
    await PushService.instance.handleRemoteMessage(message, background: true);
  } catch (e) {
    debugPrint('firebaseMessagingBackgroundHandler failed: $e');
  }
}

class PushService {
  PushService._();
  static final PushService instance = PushService._();

  bool _wired = false;
  bool _localReady = false;
  bool _coldStartHandled = false;
  String? _activeChatPeerEmail;
  String? _lastToken;

  // Se guardan para que un segundo paso por `_wireOnce()` (posible si un
  // `await` posterior lanza y `init()` reintenta) no duplique la suscripción.
  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onMessageOpenedAppSub;

  /// Lo fija/limpia la pantalla de un hilo de chat (Task 10).
  void setActiveChatPeer(String? email) => _activeChatPeerEmail = email;

  /// Se llama UNA vez tras iniciar sesión (ya hay token de sesión guardado).
  Future<void> init() async {
    try {
      await ensureFirebaseInitialized();
      await _wireOnce();

      final settings = await FirebaseMessaging.instance.requestPermission();
      final status = settings.authorizationStatus;
      if (status == AuthorizationStatus.denied ||
          status == AuthorizationStatus.deniedPermanently) {
        return; // la app funciona sin push; no se vuelve a preguntar
      }

      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _registerToken(token);

      FirebaseMessaging.instance.onTokenRefresh
          .listen(_registerToken, onError: (Object _) {});
    } catch (e) {
      debugPrint('PushService.init failed: $e');
    }
  }

  /// Inicializa el plugin de notificaciones locales y crea el canal
  /// `doliv_default`. Idempotente y barato en repeticiones: lo llaman tanto el
  /// wiring de primer plano como `handleRemoteMessage` (que también corre en el
  /// isolate de segundo plano, donde `_wireOnce()` nunca se ejecuta).
  Future<void> _ensureLocalNotifications() async {
    if (_localReady) return;

    // flutter_local_notifications 22: `initialize` recibe `settings` con nombre
    // (antes era posicional) y `show` es totalmente nombrado.
    await _localNotifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          _routeTo(normalizePushData(
            json.decode(payload) as Map<Object?, Object?>,
          ));
        } catch (e) {
          debugPrint('PushService payload decode failed: $e');
        }
      },
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    _localReady = true;
  }

  Future<void> _wireOnce() async {
    if (_wired) return;

    await _ensureLocalNotifications();
    await _handleColdStartLaunch();

    // Listeners de FCM: solo tienen sentido en el isolate de primer plano.
    // Se registran con guarda de campo para no re-suscribir en un reintento.
    _onMessageSub ??= FirebaseMessaging.onMessage.listen(handleRemoteMessage);
    _onMessageOpenedAppSub ??= FirebaseMessaging.onMessageOpenedApp.listen(
      (m) => _routeTo(normalizePushData(_asObjectMap(m.data))),
    );

    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      _routeTo(normalizePushData(_asObjectMap(initial.data)));
    }

    // Solo se marca como cableado tras completar todo el wiring, para que un
    // reintento de `init()` tras un fallo vuelva a intentarlo.
    _wired = true;
  }

  /// Arranque en frío: los mensajes son data-only, así que FCM nunca dibuja una
  /// notificación de bandeja y `onMessageOpenedApp` / `getInitialMessage()` no
  /// disparan. La única notificación tocable es la de flutter_local_notifications
  /// y, en frío, `onDidReceiveNotificationResponse` tampoco corre: hay que
  /// consultar `getNotificationAppLaunchDetails()`. Se hace una sola vez y nunca
  /// en el isolate de segundo plano (este método solo lo llama `_wireOnce()`).
  Future<void> _handleColdStartLaunch() async {
    if (_coldStartHandled) return;
    _coldStartHandled = true;
    try {
      final launch =
          await _localNotifications.getNotificationAppLaunchDetails();
      final p = launch?.notificationResponse?.payload;
      if ((launch?.didNotificationLaunchApp ?? false) &&
          p != null &&
          p.isNotEmpty) {
        // Enrutar DESPUÉS de que exista el navigator: en el arranque
        // `appNavigatorKey.currentContext` es null.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            _routeTo(normalizePushData(
              json.decode(p) as Map<Object?, Object?>,
            ));
          } catch (_) {}
        });
      }
    } catch (_) {}
  }

  /// Refresca el badge y, salvo que el hilo esté abierto, dibuja la
  /// notificación local. Público porque también lo llama el background handler.
  Future<void> handleRemoteMessage(
    RemoteMessage message, {
    bool background = false,
  }) async {
    try {
      final data = normalizePushData(_asObjectMap(message.data));

      // En el isolate de segundo plano ningún widget escucha el controlador:
      // refrescar allí es una ronda HTTP autenticada desperdiciada.
      if (!background) {
        unawaited(NotificationsController.instance.refresh(force: true));
      }

      if (!shouldShowLocalNotification(data, _activeChatPeerEmail)) return;

      // En el isolate de segundo plano `_wireOnce()` nunca corrió: hay que
      // asegurar el plugin y el canal antes de `.show()`.
      await _ensureLocalNotifications();

      final title =
          (data['title'] ?? '').isNotEmpty ? data['title']! : 'Radio Doliv';
      final tag = data['type'] == 'chat' ? 'chat:${data['entityId'] ?? ''}' : null;

      await _localNotifications.show(
        id: localNotificationId(data),
        title: title,
        body: data['body'] ?? '',
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.high,
            priority: Priority.high,
            tag: tag,
          ),
        ),
        payload: json.encode(data),
      );
    } catch (e) {
      debugPrint('PushService.handleRemoteMessage failed: $e');
    }
  }

  void _routeTo(Map<String, String> data) {
    try {
      final context = appNavigatorKey.currentContext;
      if (context == null) return;
      // NotificationRouter lee 'type' / 'entityType' / 'entityId'.
      NotificationRouter.open(context, data);
    } catch (e) {
      debugPrint('PushService._routeTo failed: $e');
    }
  }

  Future<void> _registerToken(String token) async {
    // Corre también desde `onTokenRefresh.listen(...)`: cualquier fallo aquí
    // (secure storage, red, valor inesperado) NO debe volverse un error async
    // sin capturar.
    try {
      _lastToken = token;
      final auth = await _sessionToken();
      if (auth == null) return;
      await http.post(
        Uri.parse('$kBaseUrl/devices/register'),
        headers: {'Authorization': auth},
        body: {'token': token, 'platform': 'android'},
      );
    } catch (e) {
      // se reintenta en el próximo arranque de la app
      debugPrint('PushService._registerToken failed: $e');
    }
  }

  /// Se llama al cerrar sesión, ANTES de borrar el token de sesión.
  Future<void> disable() async {
    try {
      final auth = await _sessionToken();
      final token = _lastToken ?? await _safeCurrentToken();
      if (token != null && auth != null) {
        try {
          await http.post(
            Uri.parse('$kBaseUrl/devices/unregister'),
            headers: {'Authorization': auth},
            body: {'token': token},
          );
        } catch (_) {}
      }
      try {
        await FirebaseMessaging.instance.deleteToken();
      } catch (_) {}
      _lastToken = null;
    } catch (e) {
      debugPrint('PushService.disable failed: $e');
    }
  }

  Future<String?> _sessionToken() async {
    final stored = await secureStorage.readSecureData(key);
    if (stored == null) return null;
    final s = stored as String;
    return s.isEmpty ? null : s;
  }

  Future<String?> _safeCurrentToken() async {
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (_) {
      return null;
    }
  }

  Map<Object?, Object?> _asObjectMap(Map<String, dynamic> m) =>
      m.map((k, v) => MapEntry<Object?, Object?>(k, v));
}
