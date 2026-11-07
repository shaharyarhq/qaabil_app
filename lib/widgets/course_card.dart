import 'package:flutter/material.dart';

import '../models/catalogue_course.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_tokens.dart';
import '../utils/formatters.dart';
import 'app_card.dart';

/// A playful course tile, displaying only metadata from the catalogue API.
class CourseCard extends StatelessWidget {
  const CourseCard({super.key, required this.course, this.onTap});
  final CatalogueCourse course;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (accent, tint) =
        AppColors.learningAccents[course.id % AppColors.learningAccents.length];
    return AppCard(
      padding: EdgeInsets.zero,
      borderRadius: AppRadius.panel,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 6,
                  margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (course.qualification?.isNotEmpty == true)
                            Text(
                              course.qualification!,
                              style: AppTextStyles.eyebrow.copyWith(
                                fontSize: 10,
                                letterSpacing: 0.7,
                                color: accent,
                              ),
                            ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(course.name, style: AppTextStyles.cardTitle),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Container(
                      width: 60,
                      height: 64,
                      decoration: BoxDecoration(
                        color: tint,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.2),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.16),
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.auto_stories_rounded,
                        size: 32,
                        color: accent,
                      ),
                    ),
                  ],
                ),
                if (course.description.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    course.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body,
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _Metric(
                      Icons.layers_rounded,
                      pluralize(course.sections, 'section'),
                    ),
                    _Metric(
                      Icons.menu_book_rounded,
                      pluralize(course.chapters, 'chapter'),
                    ),
                    _Metric(
                      Icons.play_circle_rounded,
                      pluralize(course.videos, 'video'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                const Divider(height: 2),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    const Expanded(
                      child: Text('Explore course', style: AppTextStyles.label),
                    ),
                    if (course.addedOn != null)
                      Text(
                        timeAgo(course.addedOn!),
                        style: AppTextStyles.caption,
                      ),
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: tint,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        color: accent,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.icon, this.text);
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
    decoration: BoxDecoration(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(11),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.textMuted),
        const SizedBox(width: 5),
        Text(
          text,
          style: AppTextStyles.caption.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}
