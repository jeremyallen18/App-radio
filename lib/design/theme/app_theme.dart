import 'package:flutter/material.dart';
import '../tokens/colors.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';

/// Tema único de la app. Toda pantalla nueva debería verse correcta
/// heredando de aquí, sin declarar un solo color propio.
///
/// [dark] y [light] se construyen con [_buildTheme] a partir de la paleta
/// congelada correspondiente ([AppColors.darkPalette] / [AppColors.lightPalette]),
/// para que ambos `ThemeData` existan siempre y `MaterialApp` pueda elegir
/// el correcto vía `themeMode` sin depender de estado global.
class AppTheme {
  AppTheme._();

  static ThemeData get dark => _buildTheme(AppColors.darkPalette, Brightness.dark);

  static ThemeData get light => _buildTheme(AppColors.lightPalette, Brightness.light);

  static ThemeData _buildTheme(AppPalette p, Brightness brightness) {
    final textTheme = AppTypography.textTheme(p.textPrimary, p.textMuted);

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: AppColors.brandBlue,
      onPrimary: p.textPrimary,
      secondary: p.accent,
      onSecondary: brightness == Brightness.dark ? p.bgBase : Colors.white,
      surface: p.surface,
      onSurface: p.textPrimary,
      error: p.error,
      onError: p.textPrimary,
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
          foregroundColor: p.textPrimary,
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
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? p.textPrimary : p.textMuted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? p.textPrimary : p.textMuted,
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
