import 'package:flutter/material.dart';

/// Qaabil's navy/amber identity with friendly, high-contrast supporting colours.
class AppColors {
  AppColors._();
  static const navy = Color(0xFF1B3A6B);
  static const navyDark = Color(0xFF122952);
  static const amber = Color(0xFFFFBF47);
  static const amberDark = Color(0xFFE59B19);
  static const amberTint = Color(0xFFFFF4D6);
  static const amberText = Color(0xFF965800);
  static const background = Color(0xFFFBFCFF);
  static const surface = Colors.white;
  static const navyTint = Color(0xFFECF2FF);
  static const textPrimary = Color(0xFF243B53);
  static const textSecondary = Color(0xFF53677F);
  static const textMuted = Color(0xFF6C7F95);
  static const border = Color(0xFFDDE5EF);
  static const error = Color(0xFFD43D46);
  static const sky = Color(0xFF249ACB);
  static const skyTint = Color(0xFFE8F7FF);
  static const violet = Color(0xFF7251B5);
  static const violetTint = Color(0xFFF1EAFF);
  static const teal = Color(0xFF147D6C);
  static const tealTint = Color(0xFFE6F8F0);
  static const coral = Color(0xFFAD4B37);
  static const coralTint = Color(0xFFFFF0E9);

  // Stable decorative accents; progress status colours keep their own meaning.
  static const learningAccents = [
    (navy, navyTint),
    (violet, violetTint),
    (teal, tealTint),
    (amberText, amberTint),
    (coral, coralTint),
  ];
}
