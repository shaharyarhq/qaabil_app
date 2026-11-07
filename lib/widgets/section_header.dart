import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_tokens.dart';

/// A friendly page introduction with a decorative book badge.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.accent,
    this.subtitle,
    this.sparkle = false,
  });

  /// Small uppercase label with the amber bar in front of it.
  final String eyebrow;

  /// The plain part of the heading.
  final String title;

  /// Emphasized words following the title.
  final String accent;

  final String? subtitle;

  /// Show the amber ✦ after the heading, like the qaabil.io courses page.
  final bool sparkle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: AppColors.amber,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(eyebrow.toUpperCase(), style: AppTextStyles.eyebrow),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: title,
                  children: [
                    TextSpan(text: accent, style: AppTextStyles.headingAccent),
                    if (sparkle)
                      const TextSpan(
                        text: ' ✦',
                        style: TextStyle(color: AppColors.amber, fontSize: 20),
                      ),
                  ],
                ),
                style: AppTextStyles.heading,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: AppColors.amberTint,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.amber, width: 2),
                boxShadow: const [
                  BoxShadow(color: AppColors.amberDark, offset: Offset(0, 4)),
                ],
              ),
              child: const Icon(
                Icons.auto_stories_rounded,
                size: 30,
                color: AppColors.navy,
              ),
            ),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(subtitle!, style: AppTextStyles.body),
        ],
      ],
    );
  }
}
