import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_tokens.dart';

/// A tappable filter option, e.g. "Cambridge IGCSE  4".
///
/// The selected pill uses the soft blue + navy look of the active link in
/// the qaabil.io nav bar.
class FilterPill extends StatelessWidget {
  const FilterPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// How many courses match this filter. Hidden when null.
  final int? count;

  @override
  Widget build(BuildContext context) {
    final textColor = selected ? AppColors.navy : AppColors.textSecondary;

    return Material(
      color: selected ? AppColors.navyTint : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.controlRadius,
        side: BorderSide(
          color: selected
              ? AppColors.navy.withValues(alpha: 0.35)
              : AppColors.border,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.controlRadius,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: AppTextStyles.label.copyWith(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: textColor,
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '$count',
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: selected ? AppColors.navy : AppColors.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
