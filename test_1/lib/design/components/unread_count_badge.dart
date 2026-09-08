import 'package:flutter/material.dart';
import '../tokens/colors.dart';

/// Burbuja circular con un número, al estilo WhatsApp/iOS, para mensajes
/// sin leer (p.ej. junto a cada chat en [MessagesDashboardScreen] o
/// encima del botón "Mensajes" del inicio). No se muestra nada si `count`
/// es 0 o menos; a partir de 100 se corta en "99+" para no desbordar el
/// círculo.
class UnreadCountBadge extends StatelessWidget {
  const UnreadCountBadge({super.key, required this.count, this.size = 20});

  final int count;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final String label = count > 99 ? '99+' : '$count';
    // Sin `alignment` en el Container: con `alignment`, un Container sin ancho
    // se expande a todo el ancho disponible, y como `trailing` de un ListTile
    // eso rompe el layout ("Trailing widget consumes the entire tile width").
    // Se centra el texto con `Center(widthFactor/heightFactor: 1)`, que mide
    // exactamente lo que ocupa el número.
    return Container(
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
  }
}
