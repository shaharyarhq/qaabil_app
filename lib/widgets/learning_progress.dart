import 'package:flutter/material.dart';

import '../models/member_course.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_tokens.dart';

/// Coverage and mastery are separate: needing practice still counts as started.
class LearningProgressView extends StatelessWidget {
  const LearningProgressView({super.key, required this.progress});
  final LearningProgress progress;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${progress.coveragePercent}% objectives started',
          style: AppTextStyles.label,
        ),
        const SizedBox(height: AppSpacing.sm),
        LinearProgressIndicator(
          value: (progress.coveragePercent / 100).clamp(0, 1),
          minHeight: 16,
          borderRadius: BorderRadius.circular(10),
          backgroundColor: AppColors.navyTint,
          semanticsLabel: 'Objectives started',
          semanticsValue: '${progress.coveragePercent}%',
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '${progress.started} of ${progress.total} objectives · ${progress.masteryPercent}% mastered',
          style: AppTextStyles.caption,
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.sm,
          children: [
            Text(
              '${progress.notStarted} Not started',
              style: AppTextStyles.caption,
            ),
            Text(
              '${progress.behind} Behind',
              style: AppTextStyles.caption.copyWith(color: AppColors.error),
            ),
            Text(
              '${progress.practice} Practice',
              style: AppTextStyles.caption.copyWith(color: AppColors.amberText),
            ),
            Text(
              '${progress.mastery} Mastery',
              style: AppTextStyles.caption.copyWith(color: AppColors.navy),
            ),
          ],
        ),
      ],
    );
  }
}
