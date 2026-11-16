import 'package:flutter/material.dart';

import 'searchable_select.dart';

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
    return SearchableSelect<CourseSort>(
      label: 'Sort courses',
      value: value,
      options: {for (final option in CourseSort.values) option: option.label},
      onChanged: (value) => onChanged(value!),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppPalette.of(context).surface,
          border: Border.all(color: AppPalette.of(context).border),
          borderRadius: AppRadius.controlRadius,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.swap_vert,
              size: 18,
              color: AppPalette.of(context).accent,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              value.label,
              style: AppTextStyles.label.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            Icon(
              Icons.expand_more,
              size: 18,
              color: AppPalette.of(context).textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
