import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Text styles used across the app.
///
/// qaabil.io pairs a clean sans-serif (Plus Jakarta Sans) with an italic
/// serif (Instrument Serif) for one or two highlighted words in headings.
class AppTextStyles {
  AppTextStyles._();

  static const String sans = 'PlusJakartaSans';
  static const String serif = 'InstrumentSerif';

  /// Big page headings, e.g. "Welcome back".
  static const TextStyle heading = TextStyle(
    fontFamily: sans,
    fontSize: 28,
    fontWeight: FontWeight.w800,
    height: 1.25,
    letterSpacing: -0.5,
    color: AppColors.textPrimary,
  );

  /// The highlighted words inside a heading.
  static const TextStyle headingAccent = TextStyle(
    fontFamily: serif,
    fontStyle: FontStyle.italic,
    fontWeight: FontWeight.w400,
    fontSize: 32,
    letterSpacing: 0,
    color: AppColors.navy,
  );

  /// Small uppercase label above a heading, e.g. "MY COURSES".
  static const TextStyle eyebrow = TextStyle(
    fontFamily: sans,
    fontSize: 11.5,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.6,
    color: AppColors.navy,
  );

  /// Big course card titles.
  static const TextStyle cardTitle = TextStyle(
    fontFamily: sans,
    fontSize: 20,
    fontWeight: FontWeight.w800,
    height: 1.3,
    letterSpacing: -0.3,
    color: AppColors.textPrimary,
  );

  /// Small uppercase text inside pills, e.g. "11 SECTIONS".
  static const TextStyle pill = TextStyle(
    fontFamily: sans,
    fontSize: 10.5,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.8,
    color: AppColors.amberText,
  );

  /// Small grey text, e.g. "📚 55 chapters".
  static const TextStyle caption = TextStyle(
    fontFamily: sans,
    fontSize: 12.5,
    fontWeight: FontWeight.w500,
    color: AppColors.textMuted,
  );

  /// Small italic serif text, e.g. "4 days ago".
  static const TextStyle serifCaption = TextStyle(
    fontFamily: serif,
    fontStyle: FontStyle.italic,
    fontSize: 14,
    color: AppColors.textMuted,
  );

  /// Card titles.
  static const TextStyle title = TextStyle(
    fontFamily: sans,
    fontSize: 16,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
  );

  /// Normal paragraph text.
  static const TextStyle body = TextStyle(
    fontFamily: sans,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.6,
    color: AppColors.textSecondary,
  );

  /// Labels above text fields.
  static const TextStyle label = TextStyle(
    fontFamily: sans,
    fontSize: 13.5,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  /// Text inside buttons.
  static const TextStyle button = TextStyle(
    fontFamily: sans,
    fontSize: 15,
    fontWeight: FontWeight.w700,
  );
}
