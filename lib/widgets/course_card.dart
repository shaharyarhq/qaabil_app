import 'package:flutter/material.dart';

import '../models/course.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_tokens.dart';
import '../utils/formatters.dart';
import 'app_card.dart';

/// One course, styled like the course cards on qaabil.io/courses:
///
///   ━━━━━━━━━━━━━━━━━━━━━━━━  (navy bar)
///   • 11 SECTIONS       4 days ago
///   Mathematics (9709)
///   Cambridge A-Level
///   Pure maths, mechanics…
///   ────────────────────────
///   📚 55 chapters    🔥 0 videos
class CourseCard extends StatelessWidget {
  const CourseCard({super.key, required this.course, this.onTap});

  final Course course;

  /// Called when the card is tapped, e.g. to open the course page.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      borderRadius: AppRadius.panel,
      // InkWell shows the tap ripple. It needs a Material behind it,
      // so we add a see-through one.
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(height: 5, color: AppColors.navy),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _SectionsPill(sections: course.sections),
                        const Spacer(),
                        Text(
                          timeAgo(course.addedOn),
                          style: AppTextStyles.serifCaption,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(course.title, style: AppTextStyles.cardTitle),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      course.qualification.label,
                      style: AppTextStyles.label.copyWith(
                        fontSize: 12.5,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(course.description, style: AppTextStyles.body),
                    const SizedBox(height: AppSpacing.lg),
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: AppColors.border,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Text(
                          '📚 ${pluralize(course.chapters, 'chapter')}',
                          style: AppTextStyles.caption,
                        ),
                        const Spacer(),
                        Text(
                          '🔥 ${pluralize(course.videos, 'video')}',
                          style: AppTextStyles.label.copyWith(
                            color: AppColors.navy,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline,
                            decorationColor: AppColors.amber,
                            decorationThickness: 2,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The amber "• 11 SECTIONS" pill in the top-left of the card.
class _SectionsPill extends StatelessWidget {
  const _SectionsPill({required this.sections});

  final int sections;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.amberTint,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.amberText.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              color: AppColors.amber,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            pluralize(sections, 'section').toUpperCase(),
            style: AppTextStyles.pill,
          ),
        ],
      ),
    );
  }
}
