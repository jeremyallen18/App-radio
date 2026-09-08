import 'package:flutter/material.dart';
import 'package:doliv_social/design/tokens/colors.dart';
import 'package:doliv_social/design/tokens/spacing.dart';

/// Scaffold estándar de la app: fondo, `SafeArea` y padding horizontal
/// coherentes. Sustituye a los `Scaffold` sueltos repetidos en cada pantalla.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.drawer,
    this.padding = const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.safeArea = true,
    this.scrollable = false,
    this.backgroundColor,
  });

  final Widget body;
  final PreferredSizeWidget? appBar;

  /// Panel lateral (menú hamburguesa). Cuando se pasa, [MyAppBar] muestra
  /// solo el botón de menú que lo abre (`Scaffold.of(context).hasDrawer`).
  final Widget? drawer;

  final EdgeInsets padding;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final bool safeArea;
  final bool scrollable;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    Widget content = Padding(padding: padding, child: body);
    if (scrollable) {
      content = SingleChildScrollView(padding: padding, child: body);
    }
    if (safeArea) {
      content = SafeArea(child: content);
    }

    return Scaffold(
      backgroundColor: backgroundColor ?? AppColors.bgBase,
      appBar: appBar,
      drawer: drawer,
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
