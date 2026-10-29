import 'package:flutter/material.dart';

import '../models/course_sort.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_tokens.dart';

/// The "Newest first ▾" button. Tapping it opens a menu of sort options.
class SortButton extends StatelessWidget {
  const SortButton({super.key, required this.value, required this.onChanged});

  final CourseSort value;
  final ValueChanged<CourseSort> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<CourseSort>(
      initialValue: value,
      onSelected: onChanged,
      tooltip: 'Sort courses',
      position: PopupMenuPosition.under,
      itemBuilder: (context) => [
        for (final option in CourseSort.values)
          PopupMenuItem(value: option, child: Text(option.label)),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: AppRadius.controlRadius,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.swap_vert, size: 18, color: AppColors.navy),
            const SizedBox(width: AppSpacing.xs),
            Text(
              value.label,
              style: AppTextStyles.label.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Icon(Icons.expand_more, size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
