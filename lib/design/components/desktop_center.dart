import 'package:flutter/widgets.dart';
import '../tokens/breakpoints.dart';

/// Envoltorio liviano para pantallas que todavía usan `Scaffold` directo (en
/// vez de `AppScaffold`): en escritorio centra el contenido en una columna
/// de ancho cómodo, igual que hace `AppScaffold.centerOnDesktop`, sin tocar
/// el resto de su estilo (fondo, gradientes, etc. quedan igual).
class DesktopCenter extends StatelessWidget {
  const DesktopCenter({super.key, required this.child, this.maxWidth});

  final Widget child;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    if (!AppBreakpoints.isDesktop(context)) return child;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth ?? AppBreakpoints.maxContentWidth,
        ),
        child: child,
      ),
    );
  }
}
