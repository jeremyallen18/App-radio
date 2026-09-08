import 'dart:async';

import 'package:flutter/material.dart';

import 'package:doliv_social/design/tokens/colors.dart';
import 'package:doliv_social/design/tokens/spacing.dart';

/// Piezas de movimiento compartidas por toda la app. Todo aquí es de bajo
/// costo: se apoya en los widgets de animación que ya trae Flutter, solo hay
/// bucles en dos sitios muy acotados (`SkeletonBox` y el pulso del botón de
/// radio) y **siempre** se respeta la preferencia de "reducir movimiento" del
/// sistema — cuando está activa, cada animación se resuelve al instante.
///
/// La convención de reduce-motion ya la usaba `completion_gauge.dart` con
/// `MediaQuery.disableAnimationsOf`; aquí se centraliza en
/// `context.reduceMotion`.

/// Duraciones estándar. Cortas a propósito: el movimiento debe acompañar, no
/// hacerse notar.
class AppDurations {
  AppDurations._();

  /// Realimentación táctil (escala al presionar).
  static const Duration micro = Duration(milliseconds: 120);

  /// Cambios pequeños (badges, chevrons, cross-fade de íconos).
  static const Duration short = Duration(milliseconds: 200);

  /// Entrada de tarjetas y pantallas.
  static const Duration medium = Duration(milliseconds: 280);

  /// Recorridos largos (barrido de gráficas, medidores).
  static const Duration long = Duration(milliseconds: 450);

  /// Un ciclo del pulso del botón de radio.
  static const Duration pulse = Duration(milliseconds: 1100);

  /// Un barrido del esqueleto de carga.
  static const Duration shimmer = Duration(milliseconds: 1400);
}

/// Curvas estándar.
class AppCurves {
  AppCurves._();

  /// Entrada / cambios: desacelera al final.
  static const Curve standard = Curves.easeOutCubic;

  /// Rebote sutil para acentuar (ícono de pestaña activa).
  static const Curve emphasized = Curves.easeOutBack;

  /// Salida: acelera al final.
  static const Curve exit = Curves.easeInCubic;
}

/// `context.reduceMotion` — el usuario pidió menos movimiento en los ajustes
/// de accesibilidad del sistema. Cuando es `true`, las animaciones deben
/// aparecer ya en su estado final (sin timers, sin controladores corriendo).
extension AppMotionContext on BuildContext {
  bool get reduceMotion => MediaQuery.maybeOf(this)?.disableAnimations ?? false;
}

/// Entrada estándar de un widget al montarse: aparece (fade) mientras sube un
/// poco (slide) y, opcionalmente, escala desde [scaleFrom].
///
/// - Con `context.reduceMotion` aparece ya visible, sin animar.
/// - [delay] permite escalonar listas: `AppFadeIn(delay: index * 40ms, …)`.
///   Úsese con tope (~6 elementos) para no encadenar decenas de timers.
class AppFadeIn extends StatefulWidget {
  const AppFadeIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = AppDurations.medium,
    this.offset = const Offset(0, 12),
    this.scaleFrom,
    this.curve = AppCurves.standard,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;

  /// Desplazamiento inicial; el widget viaja de aquí a `Offset.zero`.
  final Offset offset;

  /// Si se indica, además escala de este valor a 1 (p. ej. 0.96).
  final double? scaleFrom;

  final Curve curve;

  /// Azúcar para escalonar: `AppFadeIn.staggered(index: i, child: …)`.
  factory AppFadeIn.staggered({
    Key? key,
    required int index,
    required Widget child,
    int maxSteps = 6,
    Duration step = const Duration(milliseconds: 45),
    Duration duration = AppDurations.medium,
    Offset offset = const Offset(0, 12),
    double? scaleFrom,
  }) {
    final clamped = index < 0 ? 0 : (index > maxSteps ? maxSteps : index);
    return AppFadeIn(
      key: key,
      delay: step * clamped,
      duration: duration,
      offset: offset,
      scaleFrom: scaleFrom,
      child: child,
    );
  }

  @override
  State<AppFadeIn> createState() => _AppFadeInState();
}

class _AppFadeInState extends State<AppFadeIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  Timer? _delayTimer;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // El arranque se decide aquí porque necesita leer MediaQuery.
    if (_started) return;
    _started = true;
    if (context.reduceMotion) {
      _controller.value = 1;
    } else if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      _delayTimer = Timer(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final double raw = widget.curve.transform(_controller.value);
        final double t = raw.clamp(0.0, 1.0);
        Widget out = Opacity(opacity: t, child: child);
        if (widget.offset != Offset.zero && t < 1) {
          out = Transform.translate(
            offset: Offset(
              widget.offset.dx * (1 - raw),
              widget.offset.dy * (1 - raw),
            ),
            child: out,
          );
        }
        if (widget.scaleFrom != null && t < 1) {
          final double from = widget.scaleFrom!;
          out = Transform.scale(scale: from + (1 - from) * raw, child: out);
        }
        return out;
      },
    );
  }
}

/// Envuelve un hijo y lo encoge ligeramente mientras está presionado, como
/// realimentación táctil. Usa un [Listener] (no un GestureDetector que
/// consuma el gesto), así un [InkWell] interno sigue recibiendo el toque.
///
/// Si [onTap] se indica, además dispara ese callback. Con `reduceMotion` no
/// escala (pero sigue respondiendo al toque).
class AppPressable extends StatefulWidget {
  const AppPressable({
    super.key,
    required this.child,
    this.onTap,
    this.pressedScale = 0.97,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;
  final bool enabled;

  @override
  State<AppPressable> createState() => _AppPressableState();
}

class _AppPressableState extends State<AppPressable> {
  bool _pressed = false;

  void _set(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final bool animate = widget.enabled && !context.reduceMotion;
    Widget child = widget.child;

    if (widget.onTap != null) {
      child = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.enabled ? widget.onTap : null,
        child: child,
      );
    }

    if (!animate) return child;

    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1.0,
        duration: AppDurations.micro,
        curve: AppCurves.standard,
        child: child,
      ),
    );
  }
}

/// Transición de página fade + un desplazamiento corto hacia arriba. Se
/// engancha una sola vez en `AppTheme.dark` (`pageTransitionsTheme`), así
/// cubre todas las rutas sin tocar cada `Navigator.push`.
class AppFadeThroughPageTransitionsBuilder extends PageTransitionsBuilder {
  const AppFadeThroughPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return child;
    final CurvedAnimation curved = CurvedAnimation(
      parent: animation,
      curve: AppCurves.standard,
      reverseCurve: AppCurves.exit,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.015),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

/// Provee un único [AnimationController] en bucle para todos los
/// [SkeletonBox] que haya debajo, en vez de uno por caja. Envuelve el árbol
/// de carga de una pantalla:
///
/// ```dart
/// AppSkeletonGroup(child: Column(children: [SkeletonLine(), SkeletonBox(...)]))
/// ```
class AppSkeletonGroup extends StatefulWidget {
  const AppSkeletonGroup({super.key, required this.child});

  final Widget child;

  @override
  State<AppSkeletonGroup> createState() => _AppSkeletonGroupState();
}

class _AppSkeletonGroupState extends State<AppSkeletonGroup>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Sin movimiento => no se crea el controlador; las cajas quedan estáticas.
    if (context.reduceMotion) return;
    _controller ??= AnimationController(
      vsync: this,
      duration: AppDurations.shimmer,
    )..repeat();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SkeletonScope(animation: _controller, child: widget.child);
  }
}

class _SkeletonScope extends InheritedWidget {
  const _SkeletonScope({required this.animation, required super.child});

  final Animation<double>? animation;

  static Animation<double>? of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_SkeletonScope>()
        ?.animation;
  }

  @override
  bool updateShouldNotify(_SkeletonScope oldWidget) =>
      oldWidget.animation != animation;
}

/// Rectángulo de marcador de posición con un barrido de luz. Toma el
/// controlador de un [AppSkeletonGroup] ancestro si existe; si no, crea el
/// suyo. Con `reduceMotion` es un rectángulo plano sin animar.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 16,
    this.radius = AppRadius.chip,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  AnimationController? _own;

  Animation<double>? _resolve(BuildContext context) {
    final shared = _SkeletonScope.of(context);
    if (shared != null) return shared;
    if (context.reduceMotion) return null;
    _own ??= AnimationController(
      vsync: this,
      duration: AppDurations.shimmer,
    )..repeat();
    return _own;
  }

  @override
  void dispose() {
    _own?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Animation<double>? anim = _resolve(context);
    final Color base = AppColors.surfaceBorder.withValues(alpha: 0.35);
    final Color highlight = AppColors.surfaceBorder.withValues(alpha: 0.7);

    if (anim == null) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      );
    }

    return AnimatedBuilder(
      animation: anim,
      builder: (context, _) {
        final double dx = anim.value * 2 - 1; // -1 .. 1
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(dx - 1, 0),
              end: Alignment(dx + 1, 0),
              colors: [base, highlight, base],
              stops: const [0.35, 0.5, 0.65],
            ),
          ),
        );
      },
    );
  }
}

/// Una "línea de texto" de esqueleto (altura y radio pequeños).
class SkeletonLine extends StatelessWidget {
  const SkeletonLine({super.key, this.width, this.height = 12});

  final double? width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SkeletonBox(width: width, height: height, radius: 6);
  }
}
