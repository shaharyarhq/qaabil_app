import 'package:flutter/material.dart';

import '../auth/member_session.dart';

import '../models/curriculum.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_tokens.dart';
import '../utils/formatters.dart';
import 'app_card.dart';
import '../screens/login_screen.dart';

/// One chapter on the course page. Tap it to open or close its
/// learning objectives:
///
///   Chapter 1                                   ⌄
///   Types of number · 2 objectives
///   ─────────────────────────────────────────────
///   1.1  Identify natural numbers…
///        [Notes]  [Take Quiz]
///        ▶ YouTube player, or "🎬 No videos available yet"
class ChapterTile extends StatelessWidget {
  const ChapterTile({super.key, required this.number, required this.chapter});

  /// The chapter's position in the course, starting at 1.
  final int number;
  final Chapter chapter;

  @override
  Widget build(BuildContext context) {
    // Without a shape, ExpansionTile draws divider lines when it opens.
    const noBorder = RoundedRectangleBorder(side: BorderSide.none);

    return AppCard(
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        shape: noBorder,
        collapsedShape: noBorder,
        // Make the objective boxes fill the card's width (default: centered).
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        iconColor: AppColors.navy,
        collapsedIconColor: AppColors.textMuted,
        tilePadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xs,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        title: Text('Chapter $number', style: AppTextStyles.title),
        subtitle: Text(
          '${chapter.title} · ${pluralize(chapter.objectives.length, 'objective')}',
          style: AppTextStyles.caption,
        ),
        children: [
          for (final objective in chapter.objectives)
            _ObjectiveRow(objective: objective),
        ],
      ),
    );
  }
}

/// A learning objective with its (not yet working) actions and video area.
class _ObjectiveRow extends StatelessWidget {
  const _ObjectiveRow({required this.objective});

  final LearningObjective objective;

  /// Notes, quizzes and videos need a backend, so for now we just say so.
  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Coming soon')));
  }

  @override
  Widget build(BuildContext context) {
    // The theme makes buttons full-width; these should only be as wide
    // as their text.
    const smallButton = Size(0, 40);

    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: AppRadius.button,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${objective.code}  ',
                  style: const TextStyle(color: AppColors.amberText),
                ),
                TextSpan(text: objective.title),
              ],
            ),
            style: AppTextStyles.label,
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              OutlinedButton.icon(
                onPressed: () => _showComingSoon(context),
                icon: const Icon(Icons.description_outlined, size: 18),
                label: const Text('Notes'),
                style: OutlinedButton.styleFrom(
                  minimumSize: smallButton,
                  foregroundColor: AppColors.navy,
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.button),
                ),
              ),
              FilledButton.icon(
                onPressed: () => _showComingSoon(context),
                icon: const Icon(Icons.quiz_outlined, size: 18),
                label: const Text('Take Quiz'),
                style: FilledButton.styleFrom(
                  minimumSize: smallButton,
                  textStyle: AppTextStyles.button.copyWith(fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // Show the video if this objective has one.
          if (objective.youtubeVideoId != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  SessionScope.of(context).member == null
                      ? 'Log in to access videos'
                      : 'Member video access is being connected',
                  style: AppTextStyles.label,
                ),
                const SizedBox(height: AppSpacing.sm),
                if (SessionScope.of(context).member == null)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.lock_outline, size: 18),
                    label: const Text('Login to watch'),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    ),
                  ),
              ],
            )
          else
            Text('🎬  No videos available yet', style: AppTextStyles.caption),
        ],
      ),
    );
  }
}
