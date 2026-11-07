import 'package:flutter/material.dart';

import '../auth/member_session.dart';
import '../models/member_course.dart';
import '../services/member_api.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_card.dart';
import '../widgets/curriculum_notes.dart';
import '../utils/formatters.dart';
import '../widgets/learning_progress.dart';
import '../widgets/qaabil_app_bar.dart';
import 'login_screen.dart';
import 'objective_resources_screen.dart';

/// Actual course content and saved progress.
class MemberCourseScreen extends StatefulWidget {
  const MemberCourseScreen({super.key, required this.courseId});
  final int courseId;
  @override
  State<MemberCourseScreen> createState() => _MemberCourseScreenState();
}

class _MemberCourseScreenState extends State<MemberCourseScreen> {
  Future<MemberCourse>? _course;
  int? _memberId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final session = SessionScope.of(context);
    if (_course == null || _memberId != session.member?.id) {
      _memberId = session.member?.id;
      _course = _load(session);
    }
  }

  Future<MemberCourse> _load(MemberSession session) => session.member == null
      ? session.api.publicCourse(widget.courseId)
      : session.course(widget.courseId);

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    return Scaffold(
      appBar: const QaabilAppBar(),
      body: FutureBuilder<MemberCourse>(
        future: _course,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final error = snapshot.error;
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.screen),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      error is ApiException
                          ? error.message
                          : 'Could not load this course.',
                      textAlign: TextAlign.center,
                    ),
                    TextButton(
                      onPressed: () => setState(() {
                        _course = _load(session);
                      }),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }
          final course = snapshot.data;
          if (course == null) return const SizedBox.shrink();
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSpacing.contentMaxWidth,
              ),
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.screen),
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    decoration: BoxDecoration(
                      color: AppColors.navyTint,
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(
                        color: AppColors.navy.withValues(alpha: 0.16),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.auto_stories_rounded,
                          color: AppColors.navy,
                          size: 38,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        if (course.qualification != null) ...[
                          Text(
                            course.qualification!,
                            style: AppTextStyles.eyebrow,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                        ],
                        Text(course.name, style: AppTextStyles.heading),
                        if (course.description.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.md),
                          Text(course.description, style: AppTextStyles.body),
                        ],
                      ],
                    ),
                  ),
                  CurriculumNotes(
                    kind: 'course',
                    resourceId: course.id,
                    notes: course.notes,
                    accent: AppColors.navy,
                    tint: AppColors.navyTint,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  if (session.member != null && course.progress != null)
                    AppCard(
                      child: LearningProgressView(progress: course.progress!),
                    ),
                  const SizedBox(height: AppSpacing.xxl),
                  const Text('Course content', style: AppTextStyles.title),
                  const SizedBox(height: AppSpacing.sm),
                  const Text(
                    'Explore the sections, chapters and learning objectives.',
                    style: AppTextStyles.body,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (course.sections.isEmpty)
                    const Text('No sections have been added yet.'),
                  for (final section in course.sections)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                      child: AppCard(
                        child: Material(
                          type: MaterialType.transparency,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _SectionHeading(section: section),
                              CurriculumNotes(
                                kind: 'section',
                                resourceId: section.id,
                                notes: section.notes,
                                accent: AppColors
                                    .learningAccents[section.id %
                                        AppColors.learningAccents.length]
                                    .$1,
                                tint: AppColors
                                    .learningAccents[section.id %
                                        AppColors.learningAccents.length]
                                    .$2,
                              ),
                              if (section.chapters.isEmpty)
                                const Text('No chapters have been added yet.'),
                              for (final chapter in section.chapters)
                                ExpansionTile(
                                  key: PageStorageKey(
                                    'member-chapter-${chapter.id}',
                                  ),
                                  tilePadding: EdgeInsets.zero,
                                  leading: Container(
                                    padding: const EdgeInsets.all(9),
                                    decoration: BoxDecoration(
                                      color: AppColors
                                          .learningAccents[chapter.id %
                                              AppColors.learningAccents.length]
                                          .$2,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(
                                      Icons.menu_book_rounded,
                                      color: AppColors
                                          .learningAccents[chapter.id %
                                              AppColors.learningAccents.length]
                                          .$1,
                                    ),
                                  ),
                                  title: Text(
                                    chapter.name,
                                    style: AppTextStyles.label,
                                  ),
                                  subtitle: Text(
                                    pluralize(
                                      chapter.objectives.length,
                                      'objective',
                                    ),
                                    style: AppTextStyles.caption,
                                  ),
                                  expandedCrossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    CurriculumNotes(
                                      kind: 'chapter',
                                      resourceId: chapter.id,
                                      notes: chapter.notes,
                                      accent: AppColors
                                          .learningAccents[chapter.id %
                                              AppColors.learningAccents.length]
                                          .$1,
                                      tint: AppColors
                                          .learningAccents[chapter.id %
                                              AppColors.learningAccents.length]
                                          .$2,
                                    ),
                                    if (chapter.objectives.isEmpty)
                                      const Text(
                                        'No objectives have been added yet.',
                                      ),
                                    for (final entry
                                        in chapter.objectives.asMap().entries)
                                      _ObjectiveStep(
                                        objective: entry.value,
                                        number: entry.key + 1,
                                        isMember: session.member != null,
                                      ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ObjectiveStep extends StatelessWidget {
  const _ObjectiveStep({
    required this.objective,
    required this.number,
    required this.isMember,
  });
  final OutlineObjective objective;
  final int number;
  final bool isMember;
  @override
  Widget build(BuildContext context) {
    final color = !isMember
        ? AppColors.navy
        : switch (objective.status) {
            'mastery' => AppColors.navy,
            'practice' => AppColors.amberText,
            'behind' => AppColors.error,
            _ => AppColors.textMuted,
          };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isMember && objective.status == 'practice'
                  ? AppColors.amberTint
                  : AppColors.navyTint,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: color.withValues(alpha: 0.25),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.2),
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: isMember && objective.status == 'mastery'
                ? Icon(Icons.check_rounded, color: color)
                : Text(
                    '$number',
                    style: AppTextStyles.title.copyWith(color: color),
                  ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(objective.name, style: AppTextStyles.label),
                const SizedBox(height: AppSpacing.xs),
                TextButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => isMember
                          ? ObjectiveResourcesScreen(objectiveId: objective.id)
                          : const LoginScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.play_lesson_rounded),
                  label: Text(
                    isMember ? 'Videos & notes' : 'Login for videos & notes',
                  ),
                ),
                if (isMember)
                  Chip(
                    avatar: Icon(Icons.circle, color: color, size: 10),
                    label: Text(objective.statusLabel),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.section});
  final OutlineSection section;

  @override
  Widget build(BuildContext context) {
    final (accent, tint) = AppColors
        .learningAccents[(section.id + 1) % AppColors.learningAccents.length];
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.layers_rounded, color: accent, size: 28),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              section.name,
              style: AppTextStyles.title.copyWith(color: accent),
            ),
          ),
        ],
      ),
    );
  }
}
