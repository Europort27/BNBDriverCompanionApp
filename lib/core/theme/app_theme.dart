import 'package:flutter/material.dart';

/// Neon palette shared by the theme and custom widgets.
abstract final class NeonColors {
  static const cyan = Color(0xFF00E5FF);
  static const magenta = Color(0xFFFF2BD6);
  static const lime = Color(0xFFB7FF00);
  static const panel = Color(0xFF0D101B);
  static const surface = Color(0xFF111522);
  static const background = Color(0xFF090B12);
  static const text = Color(0xFFE5F7FF);
  static const mutedText = Color(0xFF8EA6B8);
  static const outline = Color(0xFF3A5064);
  static const border = Color(0xFF26364A);
}

/// Builds the app's dark cyberpunk theme.
abstract final class AppTheme {
  /// Returns the Material 3 dark theme with neon accents.
  static ThemeData dark() {
    const selectedLabel = NeonColors.cyan;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'monospace',
      scaffoldBackgroundColor: NeonColors.background,
      colorScheme: const ColorScheme.dark(
        primary: NeonColors.cyan,
        onPrimary: Color(0xFF001014),
        secondary: NeonColors.magenta,
        onSecondary: Color(0xFF1A0015),
        tertiary: NeonColors.lime,
        surface: NeonColors.surface,
        onSurface: NeonColors.text,
        surfaceContainerHighest: Color(0xFF1A2030),
        outline: NeonColors.outline,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: NeonColors.panel,
        foregroundColor: NeonColors.text,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: NeonColors.text,
          fontFamily: 'monospace',
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: NeonColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: NeonColors.border),
          borderRadius: BorderRadius.circular(6),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: NeonColors.cyan,
        textColor: NeonColors.text,
        subtitleTextStyle: TextStyle(color: NeonColors.mutedText),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF00B8CC),
          foregroundColor: const Color(0xFF001014),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00B8CC),
          foregroundColor: const Color(0xFF001014),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: NeonColors.panel,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: NeonColors.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: NeonColors.cyan, width: 2),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: NeonColors.surface,
        modalBackgroundColor: NeonColors.surface,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: Color(0xFF1A2030),
        contentTextStyle: TextStyle(color: NeonColors.text),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: NeonColors.cyan,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: NeonColors.panel,
        indicatorColor: NeonColors.cyan.withValues(alpha: 0.2),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? selectedLabel
                : NeonColors.mutedText,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            color: states.contains(WidgetState.selected)
                ? selectedLabel
                : NeonColors.mutedText,
          ),
        ),
      ),
    );
  }

  /// Dark button with a glowing outline in [color]; dims when disabled.
  static ButtonStyle neonButton(Color color) {
    return ElevatedButton.styleFrom(
      backgroundColor: NeonColors.panel,
      foregroundColor: color,
      disabledBackgroundColor: NeonColors.panel,
      disabledForegroundColor: NeonColors.outline,
      shadowColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
    ).copyWith(
      side: WidgetStateProperty.resolveWith(
        (states) => BorderSide(
          color: states.contains(WidgetState.disabled)
              ? NeonColors.border
              : color,
          width: 1.5,
        ),
      ),
      elevation: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled) ? 0 : 6,
      ),
    );
  }
}
