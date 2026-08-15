import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../tokens/colors.dart';
import '../tokens/spacing.dart';

/// Botón "Volver" — visible solo en escritorio (Windows/macOS/Linux) y solo
/// cuando hay una ruta anterior a la que volver. En Android/iOS se oculta
/// siempre: ahí ya existe el gesto/botón nativo de retroceso del sistema.
///
/// Dos formas de usarlo:
/// - En un `AppBar` propio: `leading: AppBackButton.leadingFor(context)`
///   junto con `automaticallyImplyLeading: false`, para no reservar espacio
///   de más ni duplicar el back automático de Flutter.
/// - En pantallas sin `AppBar` (fondos con gradiente, headers propios):
///   [FloatingBackButton], superpuesto con `Stack`.
class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key, this.color});

  final Color? color;

  static bool get isDesktopPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
        return true;
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.fuchsia:
        return false;
    }
  }

  /// `null` cuando no aplica (móvil, o sin ruta anterior), para usar como
  /// `AppBar.leading` sin que Flutter reserve espacio para un botón que no
  /// se va a mostrar.
  static Widget? leadingFor(BuildContext context) {
    if (!isDesktopPlatform || !Navigator.canPop(context)) return null;
    return const AppBackButton();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.arrow_back, color: color),
      tooltip: 'Volver',
      onPressed: () => Navigator.pop(context),
    );
  }
}

/// Variante flotante de [AppBackButton] para pantallas sin `AppBar` propio
/// (fondos con gradiente, headers hechos a mano). Se posiciona con `Stack` +
/// `Align(alignment: Alignment.topLeft)` sobre el contenido existente sin
/// alterar su layout. No dibuja nada (`SizedBox.shrink`) cuando no aplica.
class FloatingBackButton extends StatelessWidget {
  const FloatingBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    if (!AppBackButton.isDesktopPlatform || !Navigator.canPop(context)) {
      return const SizedBox.shrink();
    }
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Material(
          color: AppColors.surface,
          shape: const CircleBorder(),
          elevation: 2,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => Navigator.pop(context),
            child: const Padding(
              padding: EdgeInsets.all(AppSpacing.sm),
              child: Icon(Icons.arrow_back, color: AppColors.textPrimary, size: 20),
            ),
          ),
        ),
      ),
    );
  }
}
