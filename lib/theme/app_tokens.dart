import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Spacing scale. Use these for padding and gaps between widgets.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;

  /// Padding on the left and right edges of every screen.
  static const double screen = 20;

  /// Widest a form can get on tablets / landscape, so it doesn't stretch.
  static const double formMaxWidth = 440;

  /// Widest a list of content can get on tablets / landscape.
  static const double contentMaxWidth = 640;

  /// Widest a grid of cards can get (the courses page).
  static const double gridMaxWidth = 1040;

  /// Screens at least this wide show two course cards per row.
  static const double twoColumnBreakpoint = 600;
}

/// Corner radii, matching the rounded corners on qaabil.io.
class AppRadius {
  AppRadius._();

  static const double sm = 12; // small chips, nav pills
  static const double md = 16; // buttons and text fields
  static const double control = 18; // search bar, filters, sort menu
  static const double lg = 22; // cards
  static const double xl = 26; // large feature cards, course cards

  static BorderRadius get button => BorderRadius.circular(md);
  static BorderRadius get controlRadius => BorderRadius.circular(control);
  static BorderRadius get card => BorderRadius.circular(lg);
  static BorderRadius get panel => BorderRadius.circular(xl);
}

/// Crisp lower edges give cards a friendly, tactile appearance.
class AppShadows {
  AppShadows._();
  static List<BoxShadow> get card => const [
    BoxShadow(color: AppColors.border, offset: Offset(0, 4), blurRadius: 0),
  ];
  static List<BoxShadow> get raised => const [
    BoxShadow(color: AppColors.border, offset: Offset(0, 6), blurRadius: 0),
  ];
}
