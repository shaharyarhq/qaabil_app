import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

/// A white card with a thin border and a soft navy shadow,
/// like the cards on qaabil.io.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
    this.raised = false,
    this.borderRadius,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Use a bigger shadow and rounder corners, for a card that stands alone.
  final bool raised;

  /// Override the corner radius. Defaults depend on [raised].
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      // Clip the child to the rounded corners (needed for the course card's
      // colored top bar).
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius:
            borderRadius ?? (raised ? AppRadius.panel : AppRadius.card),
        boxShadow: raised ? AppShadows.raised : AppShadows.card,
      ),
      child: child,
    );
  }
}
