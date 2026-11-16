import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';
import 'app_tokens.dart';

/// Builds the app's [ThemeData] from the design tokens.
///
/// Default Material widgets (buttons, text fields, app bars) pick up these
/// styles automatically, so screens rarely need to style them by hand.
class AppTheme {
  AppTheme._();

  static final light = _build(const AppPalette(false));
  static final dark = _build(const AppPalette(true));

  static ThemeData _build(AppPalette palette) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.navy,
      brightness: palette.dark ? Brightness.dark : Brightness.light,
      primary: palette.accent,
      onPrimary: palette.dark ? AppColors.navyDark : Colors.white,
      secondary: AppColors.amber,
      onSecondary: AppColors.navy,
      primaryContainer: palette.navyTint,
      onPrimaryContainer: palette.accent,
      surface: palette.surface,
      onSurface: palette.textPrimary,
      onSurfaceVariant: palette.textSecondary,
      outline: palette.border,
      outlineVariant: palette.border,
      error: palette.error,
    );

    final buttonShape = RoundedRectangleBorder(borderRadius: AppRadius.button);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: AppTextStyles.sans,
      scaffoldBackgroundColor: palette.background,

      appBarTheme: AppBarTheme(
        backgroundColor: palette.surface,
        foregroundColor: palette.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        // A thin bottom line instead of a shadow, like the website's nav bar.
        shape: Border(bottom: BorderSide(color: palette.border, width: 2)),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style:
            FilledButton.styleFrom(
              backgroundColor: AppColors.navy,
              foregroundColor: Colors.white,
              minimumSize: const Size(64, 54),
              shape: buttonShape,
              textStyle: AppTextStyles.button,
              elevation: 0,
            ).copyWith(
              // Darker navy while pressed, instead of the default ripple tint.
              foregroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.disabled)
                    ? palette.textSecondary
                    : Colors.white,
              ),
              backgroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.disabled)
                    ? palette.border
                    : states.contains(WidgetState.pressed)
                    ? AppColors.navyDark
                    : AppColors.navy,
              ),
            ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.accent,
          shape: buttonShape,
          textStyle: AppTextStyles.button.copyWith(fontSize: 14),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        hintStyle: AppTextStyles.body.copyWith(color: palette.textMuted),
        prefixIconColor: palette.textMuted,
        enabledBorder: inputBorder(palette.border),
        focusedBorder: inputBorder(palette.accent),
        errorBorder: inputBorder(palette.error),
        focusedErrorBorder: inputBorder(palette.error),
      ),

      // Menus that pop up, like the "Newest first" sort menu.
      popupMenuTheme: PopupMenuThemeData(
        color: palette.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: AppColors.navy.withValues(alpha: 0.25),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.controlRadius,
          side: BorderSide(color: palette.border),
        ),
        textStyle: AppTextStyles.label,
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
          foregroundColor: palette.accent,
          side: BorderSide(color: palette.border, width: 2),
          shape: buttonShape,
          textStyle: AppTextStyles.button,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: palette.surface,
        elevation: 0,
        height: 80,
        indicatorColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: AppTextStyles.sans,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: states.contains(WidgetState.selected)
                ? palette.accent
                : palette.textMuted,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: palette.surface,
        selectedColor: palette.navyTint,
        side: BorderSide(color: palette.border, width: 2),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.button),
        labelStyle: AppTextStyles.label,
      ),
      dividerTheme: DividerThemeData(color: palette.border, thickness: 2),
      expansionTileTheme: ExpansionTileThemeData(
        iconColor: palette.accent,
        collapsedIconColor: palette.textMuted,
        shape: const Border(),
        collapsedShape: const Border(),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: palette.accent,
        selectionColor: AppColors.navy.withValues(alpha: 0.15),
        selectionHandleColor: palette.accent,
      ),
    );
  }

  /// The outline used around text fields. Pass [radius] to change the corners.
  static OutlineInputBorder inputBorder(Color color, {BorderRadius? radius}) {
    return OutlineInputBorder(
      borderRadius: radius ?? AppRadius.button,
      borderSide: BorderSide(color: color, width: 2),
    );
  }
}
