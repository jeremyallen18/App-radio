import 'package:flutter/material.dart';
import '../tokens/breakpoints.dart';
import '../tokens/colors.dart';
import '../tokens/spacing.dart';
import 'app_back_button.dart';

/// Scaffold estándar de la app: fondo, `SafeArea` y padding horizontal
/// coherentes. Sustituye a los `Scaffold` sueltos repetidos en cada pantalla.
///
/// En escritorio, si [centerOnDesktop] es true (default), el contenido se
/// centra en una columna de ancho cómodo para lectura/formularios — pantallas
/// de una sola tarjeta (login, detalle, etc.) quieren esto. El shell
/// principal (`BottomNavBar`) pasa `centerOnDesktop: false` para aprovechar
/// todo el ancho con su barra lateral y grillas de varias columnas.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.padding = const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.safeArea = true,
    this.scrollable = false,
    this.backgroundColor,
    this.centerOnDesktop = true,
    this.showBackButton = true,
  });

  final Widget body;
  final PreferredSizeWidget? appBar;
  final EdgeInsets padding;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final bool safeArea;
  final bool scrollable;
  final Color? backgroundColor;
  final bool centerOnDesktop;

  /// Muestra [FloatingBackButton] superpuesto arriba a la izquierda cuando
  /// esta pantalla no trae su propio [appBar] (las que sí lo traen controlan
  /// su back button con `AppBackButton.leadingFor` en el propio `AppBar`).
  /// [FloatingBackButton] ya decide por su cuenta si corresponde mostrarse
  /// (escritorio + ruta anterior válida), así que este flag solo sirve para
  /// que una pantalla puntual lo desactive explícitamente si hiciera falta.
  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    Widget content = Padding(padding: padding, child: body);
    if (scrollable) {
      content = SingleChildScrollView(padding: padding, child: body);
    }
    if (centerOnDesktop && AppBreakpoints.isDesktop(context)) {
      content = Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppBreakpoints.maxContentWidth,
          ),
          child: content,
        ),
      );
    }
    if (safeArea) {
      content = SafeArea(child: content);
    }
    if (showBackButton && appBar == null) {
      content = Stack(
        children: [
          content,
          const Align(alignment: Alignment.topLeft, child: FloatingBackButton()),
        ],
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor ?? AppColors.bgBase,
      appBar: appBar,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: content,
      ),
    );
  }
}
