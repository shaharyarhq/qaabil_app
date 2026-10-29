import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_tokens.dart';

/// The heading pattern used all over qaabil.io:
///
///   ▬ SMALL LABEL
///   A bold heading with *italic serif* words
///   Optional grey subtitle.
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

  /// The words shown in the italic serif font, after [title].
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
              width: 18,
              height: 3,
              decoration: BoxDecoration(
                color: AppColors.amber,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(eyebrow.toUpperCase(), style: AppTextStyles.eyebrow),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text.rich(
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
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(subtitle!, style: AppTextStyles.body),
        ],
      ],
    );
  }
}
