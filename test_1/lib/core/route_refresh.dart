import 'package:flutter/widgets.dart';

/// Observador global de rutas. Registrado en `MaterialApp.navigatorObservers`
/// (ver `main.dart`), permite que una pantalla sepa cuándo vuelve a quedar
/// visible porque se cerró la que tenía encima.
final RouteObserver<PageRoute<dynamic>> routeObserver =
    RouteObserver<PageRoute<dynamic>>();

/// Mixin para una pantalla con lista/datos que deben refrescarse al volver a
/// ella (p. ej. tras crear/editar algo en una pantalla hija). Implementa la
/// suscripción/cancelación al [routeObserver]; la pantalla solo define
/// [onRouteReenter] llamando a su propio método de carga.
///
/// No refresca en el primer `push` (para eso está `initState`), solo cuando
/// se REGRESA a la pantalla.
mixin RouteAwareRefresh<T extends StatefulWidget> on State<T>
    implements RouteAware {
  ModalRoute<dynamic>? _subscribedRoute;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute && route != _subscribedRoute) {
      if (_subscribedRoute != null) routeObserver.unsubscribe(this);
      routeObserver.subscribe(this, route);
      _subscribedRoute = route;
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  /// Se llama cuando esta pantalla vuelve a quedar arriba de la pila.
  void onRouteReenter();

  @override
  void didPopNext() => onRouteReenter();

  @override
  void didPushNext() {}

  @override
  void didPush() {}

  @override
  void didPop() {}
}
