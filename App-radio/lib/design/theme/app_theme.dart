import 'package:flutter/material.dart';
import 'package:doliv_social/design/motion/app_motion.dart';
import 'package:doliv_social/design/tokens/colors.dart';
import 'package:doliv_social/design/tokens/spacing.dart';
import 'package:doliv_social/design/tokens/typography.dart';

/// Tema de la app. Toda pantalla nueva debería verse correcta heredando de
/// aquí, sin declarar un solo color propio.
///
/// [dark] y [light] se construyen con [_buildTheme] a partir de la paleta
/// congelada correspondiente ([AppColors.darkPalette] / [AppColors.lightPalette]),
/// para que ambos `ThemeData` existan siempre y `MaterialApp` pueda elegir el
/// correcto vía `themeMode` sin depender del estado global de [AppColors].
class AppTheme {
  AppTheme._();

  static ThemeData get dark =>
      _buildTheme(AppColors.darkPalette, Brightness.dark);

  static ThemeData get light =>
      _buildTheme(AppColors.lightPalette, Brightness.light);

  static ThemeData _buildTheme(AppPalette p, Brightness brightness) {
    final textTheme = AppTypography.textTheme(p.textPrimary, p.textMuted);

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: AppColors.brandBlue,
      // `primary` (brandBlue) y `error` son fondos que NO cambian con el
      // modo, así que lo que va encima (onPrimary/onError) debe quedar fijo
      // en blanco: p.textPrimary sí cambia y en claro es casi negro,
      // invisible contra el azul/rojo.
      onPrimary: AppColors.onBrand,
      secondary: p.accent,
      onSecondary: brightness == Brightness.dark ? p.bgBase : Colors.white,
      surface: p.surface,
      onSurface: p.textPrimary,
      error: p.error,
      onError: AppColors.onBrand,
      outline: p.surfaceBorder,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: p.bgBase,
      fontFamily: AppTypography.fontFamily,
      textTheme: textTheme,
      splashColor: p.accent.withValues(alpha: 0.12),
      highlightColor: Colors.transparent,

      // Transición de página común (fade + desplazamiento corto).
      // Respeta "reducir movimiento" (ver el builder).
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: AppFadeThroughPageTransitionsBuilder(),
          TargetPlatform.iOS: AppFadeThroughPageTransitionsBuilder(),
        },
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: p.bgBase,
        foregroundColor: p.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: IconThemeData(color: p.textPrimary),
      ),

      inputDecorationTheme: InputDecorationTheme(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.lg,
        ),
        filled: true,
        fillColor: p.surface,
        hintStyle: TextStyle(color: p.textMuted, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.field),
          borderSide: BorderSide(color: p.surfaceBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.field),
          borderSide: BorderSide(color: p.surfaceBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.field),
          borderSide: BorderSide(color: p.accentStrong, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.field),
          borderSide: BorderSide(color: p.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.field),
          borderSide: BorderSide(color: p.error, width: 2),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brandBlue,
          // Fondo del botón siempre azul (brandBlue no cambia con el modo):
          // el texto/ícono debe quedar fijo en blanco, no en p.textPrimary.
          foregroundColor: AppColors.onBrand,
          disabledBackgroundColor: p.surface,
          disabledForegroundColor: p.textMuted,
          // Ancho finito a propósito: `Size.fromHeight` fija un ancho MÍNIMO
          // infinito, que revienta (BoxConstraints "NOT NORMALIZED") en
          // cualquier botón que además reciba un `maximumSize` explícito
          // (p. ej. teams.dart) porque min > max.
          minimumSize: const Size(64, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: p.accent),
      ),

      // FAB siempre azul de marca con contenido blanco en ambos modos (el
      // `ColorScheme` sin `fromSeed` no deriva un `primaryContainer` usable).
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.brandBlue,
        foregroundColor: AppColors.onBrand,
      ),

      // `FilledButton` (no cubierto por elevatedButtonTheme): mismo criterio
      // que el botón elevado — fondo azul de marca, contenido blanco fijo.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.brandBlue,
          foregroundColor: AppColors.onBrand,
          disabledBackgroundColor: p.surface,
          disabledForegroundColor: p.textMuted,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.accent,
          side: BorderSide(color: p.accent),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
        ),
      ),

      iconTheme: IconThemeData(color: p.textMuted),

      dividerTheme: DividerThemeData(
        color: p.surfaceBorder,
        thickness: 1,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.surface,
        contentTextStyle: TextStyle(color: p.textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.chip),
          side: BorderSide(color: p.surfaceBorder),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.surface,
        indicatorColor: AppColors.brandBlue,
        // El "pill" detrás del ítem seleccionado siempre es brandBlue (fijo),
        // así que su ícono/etiqueta deben quedar fijos en blanco
        // (AppColors.onBrand): en modo claro p.textPrimary es casi negro y se
        // pierde contra el azul del indicador.
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? AppColors.onBrand : p.textMuted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? AppColors.onBrand : p.textMuted,
          );
        }),
      ),

      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? AppColors.brandBlue
              : p.surfaceBorder;
        }),
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? AppColors.brandBlue
              : Colors.transparent;
        }),
        side: BorderSide(color: p.surfaceBorder),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.accent,
      ),
    );
  }
}
