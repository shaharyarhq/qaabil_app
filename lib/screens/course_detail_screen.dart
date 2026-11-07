import 'package:flutter/material.dart';

import '../models/course.dart';
import '../models/curriculum.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_tokens.dart';
import '../utils/formatters.dart';
import '../widgets/app_card.dart';
import '../widgets/chapter_tile.dart';
import '../widgets/qaabil_app_bar.dart';

/// The page for one course, following the layout of qaabil.io/courses/18:
/// title, a row of stats, then every section with its chapters.
///
/// It only shows data and never changes, so it is a StatelessWidget.
/// (Each chapter remembers whether it is open by itself.)
class CourseDetailScreen extends StatelessWidget {
  const CourseDetailScreen({super.key, required this.course});

  final Course course;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Flutter adds the ← back button automatically, because this screen
      // was opened with Navigator.push.
      appBar: const QaabilAppBar(),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppSpacing.contentMaxWidth,
          ),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.screen),
            children: [
              _Breadcrumb(courseTitle: course.title),
              const SizedBox(height: AppSpacing.md),
              Text(course.title, style: AppTextStyles.heading),
              const SizedBox(height: AppSpacing.xs),
              Text(
                course.qualification.label,
                style: AppTextStyles.label.copyWith(color: AppColors.navy),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(course.description, style: AppTextStyles.body),
              const SizedBox(height: AppSpacing.xl),
              _StatsRow(course: course),
              const SizedBox(height: AppSpacing.xxl),
              ..._buildCurriculum(),
              const SizedBox(height: AppSpacing.xl),
              const _UnlockInfo(),
            ],
          ),
        ),
      ),
    );
  }

  /// One block per section. Chapters are numbered across the whole
  /// course (Chapter 1, 2, 3…), like on the website.
  List<Widget> _buildCurriculum() {
    final widgets = <Widget>[];
    var chapterNumber = 0;

    for (var i = 0; i < course.curriculum.length; i++) {
      final section = course.curriculum[i];

      widgets.add(_SectionHeading(number: i + 1, section: section));
      widgets.add(const SizedBox(height: AppSpacing.md));

      if (section.chapters.isEmpty) {
        widgets.add(const _NoChapters());
      }
      for (final chapter in section.chapters) {
        chapterNumber++;
        widgets.add(ChapterTile(number: chapterNumber, chapter: chapter));
        widgets.add(const SizedBox(height: AppSpacing.md));
      }
      widgets.add(const SizedBox(height: AppSpacing.lg));
    }
    return widgets;
  }
}

/// "Courses ✦ Physics (0625)" above the title.
class _Breadcrumb extends StatelessWidget {
  const _Breadcrumb({required this.courseTitle});

  final String courseTitle;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: 'Courses',
        children: [
          const TextSpan(
            text: '  ✦  ',
            style: TextStyle(color: AppColors.amber),
          ),
          TextSpan(
            text: courseTitle,
            style: const TextStyle(color: AppColors.navy),
          ),
        ],
      ),
      style: AppTextStyles.caption,
    );
  }
}

/// The four numbers under the title: sections, chapters, objectives, videos.
class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.course});

  final Course course;

  @override
  Widget build(BuildContext context) {
    final stats = {
      'Sections': course.sections,
      'Chapters': course.chapters,
      'Objectives': course.objectives,
      'Videos': course.videos,
    };

    // Each stat gets an equal share of the width.
    return Row(
      children: [
        for (final entry in stats.entries) ...[
          if (entry.key != 'Sections') const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: AppCard(
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.md,
                horizontal: AppSpacing.sm,
              ),
              child: Column(
                children: [
                  Text(
                    '${entry.value}',
                    style: AppTextStyles.cardTitle.copyWith(
                      color: AppColors.navy,
                    ),
                  ),
                  Text(
                    entry.key,
                    style: AppTextStyles.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// "SECTION 1" pill, the section's title and how many chapters it has.
class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.number, required this.section});

  final int number;
  final CourseSection section;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.amberTint,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text('SECTION $number', style: AppTextStyles.pill),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: Text(section.title, style: AppTextStyles.title)),
        Text(
          pluralize(section.chapters.length, 'chapter'),
          style: AppTextStyles.serifCaption,
        ),
      ],
    );
  }
}

/// Shown inside a section that has no chapters yet.
class _NoChapters extends StatelessWidget {
  const _NoChapters();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      child: Text(
        'No chapters have been added to this section yet.',
        style: AppTextStyles.body,
      ),
    );
  }
}

/// The navy box at the bottom explaining how videos unlock chapters.
class _UnlockInfo extends StatelessWidget {
  const _UnlockInfo();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: AppRadius.panel,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              text: 'Upload an approved video ',
              children: [
                TextSpan(
                  text: '✦ ',
                  style: TextStyle(color: AppColors.amber),
                ),
                TextSpan(
                  text: 'unlock any chapter',
                  style: TextStyle(
                    fontFamily: AppTextStyles.serif,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w400,
                    fontSize: 22,
                    color: AppColors.amber,
                  ),
                ),
              ],
            ),
            style: AppTextStyles.title.copyWith(
              color: Colors.white,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Every course contains chapters with clear objectives. Students '
            'submit video solutions. One approved video unlocks the rest — '
            'crowdsourced, peer-validated.',
            style: AppTextStyles.body.copyWith(
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}
