import 'package:flutter/material.dart';
import '../motion/app_motion.dart';
import '../tokens/colors.dart';

/// Burbuja circular con un número, al estilo WhatsApp/iOS, para mensajes
/// sin leer (p.ej. junto a cada chat en [MessagesDashboardScreen] o
/// encima del botón "Mensajes" del inicio). No se muestra nada si `count`
/// es 0 o menos; a partir de 100 se corta en "99+" para no desbordar el
/// círculo.
///
/// Cuando el número cambia (llega un mensaje nuevo) la burbuja da un pequeño
/// "pop" de escala para que se note. Con "reducir movimiento" solo cambia el
/// texto.
class UnreadCountBadge extends StatefulWidget {
  const UnreadCountBadge({super.key, required this.count, this.size = 20});

  final int count;
  final double size;

  @override
  State<UnreadCountBadge> createState() => _UnreadCountBadgeState();
}

class _UnreadCountBadgeState extends State<UnreadCountBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: AppDurations.short,
    lowerBound: 0,
    upperBound: 1,
    value: 1,
  );

  @override
  void didUpdateWidget(covariant UnreadCountBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.count != oldWidget.count &&
        widget.count > 0 &&
        !context.reduceMotion) {
      _pop
        ..value = 0
        ..forward();
    }
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.count <= 0) return const SizedBox.shrink();
    final double size = widget.size;
    final String label = widget.count > 99 ? '99+' : '${widget.count}';

    // Sin `alignment` en el Container: con `alignment`, un Container sin ancho
    // se expande a todo el ancho disponible, y como `trailing` de un ListTile
    // eso rompe el layout ("Trailing widget consumes the entire tile width").
    // Se centra el texto con `Center(widthFactor/heightFactor: 1)`, que mide
    // exactamente lo que ocupa el número.
    final Widget bubble = Container(
      height: size,
      constraints: BoxConstraints(minWidth: size),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: AppColors.error,
        borderRadius: BorderRadius.circular(size / 2),
      ),
      child: Center(
        widthFactor: 1,
        heightFactor: 1,
        child: Text(
          label,
          maxLines: 1,
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.55,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
      ),
    );

    return ScaleTransition(
      scale: Tween<double>(begin: 0.6, end: 1.0).animate(
        CurvedAnimation(parent: _pop, curve: AppCurves.emphasized),
      ),
      child: bubble,
    );
  }
}
