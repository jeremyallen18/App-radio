import 'package:flutter/widgets.dart';

/// Observador global de rutas (registrado en `MaterialApp.navigatorObservers`).
final RouteObserver<PageRoute<dynamic>> routeObserver =
    RouteObserver<PageRoute<dynamic>>();

/// Mixin que refresca la pantalla al REGRESAR a ella (no en el primer push).
/// La pantalla solo implementa [onRouteReenter] con su método de carga.
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
