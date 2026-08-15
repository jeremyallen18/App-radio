import 'package:flutter/widgets.dart';
import '../tokens/breakpoints.dart';

/// Lista de tarjetas de tamaño similar (equipos, departamentos, tareas) que
/// fluye a 2-3 columnas cuando hay ancho de sobra, en vez de quedarse en una
/// sola columna angosta en medio de una ventana de escritorio.
///
/// En móvil (`columnsForWidth` = 1) se comporta como una `Column` normal.
class ResponsiveCardGrid extends StatelessWidget {
  const ResponsiveCardGrid({
    super.key,
    required this.children,
    this.spacing = 12,
    this.runSpacing = 12,
  });

  final List<Widget> children;
  final double spacing;
  final double runSpacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final int columns = AppBreakpoints.columnsForWidth(constraints.maxWidth);
        if (columns <= 1) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int i = 0; i < children.length; i++) ...[
                if (i > 0) SizedBox(height: runSpacing),
                children[i],
              ],
            ],
          );
        }
        final double itemWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: [
            for (final child in children)
              SizedBox(width: itemWidth, child: child),
          ],
        );
      },
    );
  }
}
