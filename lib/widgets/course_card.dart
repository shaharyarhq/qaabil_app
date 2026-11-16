import 'package:flutter/material.dart';

import '../models/catalogue_course.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/formatters.dart';

/// A course tile using metadata from the public catalogue API.
class CourseCard extends StatelessWidget {
  const CourseCard({super.key, required this.course, this.onTap});

  final CatalogueCourse course;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final date = course.updatedOn ?? course.addedOn;
    return Material(
      color: AppPalette.of(context).surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppPalette.of(context).border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 320),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ColoredBox(
                color: AppPalette.of(context).accent,
                child: SizedBox(height: 5),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: _SectionCount(count: course.sections),
                          ),
                          if (date != null) ...[
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                timeAgo(date),
                                textAlign: TextAlign.end,
                                style: TextStyle(
                                  fontFamily: AppTextStyles.serif,
                                  fontStyle: FontStyle.italic,
                                  color: AppPalette.of(context).textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        course.name,
                        style: AppTextStyles.cardTitle.copyWith(
                          color: AppPalette.of(context).textPrimary,
                          fontSize: 21,
                        ),
                      ),
                      if (course.description.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          course.description,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.body.copyWith(
                            color: AppPalette.of(context).textSecondary,
                          ),
                        ),
                      ],
                      const Spacer(),
                      const SizedBox(height: 20),
                      Divider(height: 1, color: AppPalette.of(context).border),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: _CourseMetric(
                              icon: Icons.menu_book_outlined,
                              color: AppPalette.of(context).teal,
                              text: pluralize(course.chapters, 'chapter'),
                              style: AppTextStyles.caption,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: _CourseMetric(
                              icon: Icons.local_fire_department_rounded,
                              color: const Color(0xFFE87917),
                              text: pluralize(course.videos, 'video'),
                              style: AppTextStyles.label.copyWith(
                                color: AppPalette.of(context).accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CourseMetric extends StatelessWidget {
  const _CourseMetric({
    required this.icon,
    required this.color,
    required this.text,
    required this.style,
  });

  final IconData icon;
  final Color color;
  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    spacing: 4,
    children: [
      Icon(icon, size: 14, color: color),
      Flexible(child: Text(text, style: style)),
    ],
  );
}

class _SectionCount extends StatelessWidget {
  const _SectionCount({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: AppPalette.of(context).amberTint,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: const Color(0x26B45309)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.circle, color: Color(0xFFF59E0B), size: 5),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            pluralize(count, 'section').toUpperCase(),
            style: AppTextStyles.pill.copyWith(
              color: AppPalette.of(context).amberText,
            ),
          ),
        ),
      ],
    ),
  );
}
