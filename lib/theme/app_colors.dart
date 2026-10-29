import 'package:flutter/material.dart';

/// Brand colors taken from qaabil.io.
///
/// Use these names instead of writing hex values in screens, so the
/// whole app can be re-colored from this one file.
class AppColors {
  AppColors._();

  // Brand
  static const Color navy = Color(0xFF1B3A6B); // main brand color
  static const Color navyDark = Color(0xFF122952); // pressed navy buttons
  static const Color amber = Color(0xFFF59E0B); // accent bars, highlights
  static const Color amberDark = Color(0xFFD97706);
  static const Color amberTint = Color(0xFFFFFBEB); // pill background
  static const Color amberText = Color(0xFFB45309); // pill text

  // Backgrounds
  static const Color background = Color(0xFFF8FAFD); // page background
  static const Color surface = Colors.white; // cards, inputs, app bar
  static const Color navyTint = Color(0xFFEFF6FF); // soft blue fill

  // Text
  static const Color textPrimary = Color(0xFF0F172A); // headings
  static const Color textSecondary = Color(0xFF475569); // body text
  static const Color textMuted = Color(0xFF94A3B8); // hints, small print

  // Lines
  static const Color border = Color(0xFFE2E8F0);

  static const Color error = Color(0xFFDC2626);
}
