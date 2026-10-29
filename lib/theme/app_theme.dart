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

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.navy,
      primary: AppColors.navy,
      onPrimary: Colors.white,
      secondary: AppColors.amber,
      onSecondary: AppColors.navy,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      error: AppColors.error,
    );

    final buttonShape = RoundedRectangleBorder(borderRadius: AppRadius.button);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: AppTextStyles.sans,
      scaffoldBackgroundColor: AppColors.background,

      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        // A thin bottom line instead of a shadow, like the website's nav bar.
        shape: Border(bottom: BorderSide(color: AppColors.border)),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style:
            FilledButton.styleFrom(
              backgroundColor: AppColors.navy,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(52),
              shape: buttonShape,
              textStyle: AppTextStyles.button,
            ).copyWith(
              // Darker navy while pressed, instead of the default ripple tint.
              backgroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.pressed)
                    ? AppColors.navyDark
                    : AppColors.navy,
              ),
            ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.navy,
          shape: buttonShape,
          textStyle: AppTextStyles.button.copyWith(fontSize: 14),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        hintStyle: AppTextStyles.body.copyWith(color: AppColors.textMuted),
        prefixIconColor: AppColors.textMuted,
        enabledBorder: inputBorder(AppColors.border),
        focusedBorder: inputBorder(AppColors.navy),
        errorBorder: inputBorder(AppColors.error),
        focusedErrorBorder: inputBorder(AppColors.error),
      ),

      // Menus that pop up, like the "Newest first" sort menu.
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: AppColors.navy.withValues(alpha: 0.25),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.controlRadius,
          side: const BorderSide(color: AppColors.border),
        ),
        textStyle: AppTextStyles.label,
      ),

      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.navy,
        selectionColor: AppColors.navy.withValues(alpha: 0.15),
        selectionHandleColor: AppColors.navy,
      ),
    );
  }

  /// The outline used around text fields. Pass [radius] to change the corners.
  static OutlineInputBorder inputBorder(Color color, {BorderRadius? radius}) {
    return OutlineInputBorder(
      borderRadius: radius ?? AppRadius.button,
      borderSide: BorderSide(color: color, width: 1.5),
    );
  }
}
