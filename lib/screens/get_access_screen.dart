import 'package:flutter/material.dart';

import '../theme/app_text_styles.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_card.dart';
import '../widgets/qaabil_app_bar.dart';

/// Public explanation of Qaabil's contribution model.
class GetAccessScreen extends StatelessWidget {
  const GetAccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const QaabilAppBar(),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppSpacing.contentMaxWidth,
          ),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.screen),
            children: [
              const Text('GET ACCESS', style: AppTextStyles.eyebrow),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Learn. Contribute. Grow.',
                style: AppTextStyles.heading,
              ),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'Explore course outlines for free. Qaabil is built around students sharing educational videos and learning from one another.',
                style: AppTextStyles.body,
              ),
              const SizedBox(height: AppSpacing.xxl),
              for (final step in const [
                (
                  title: '1. Submit a video',
                  text: 'Teach a learning objective or explain a related question.',
                ),
                (
                  title: '2. Get reviewed',
                  text: 'A moderator reviews the submission and provides feedback.',
                ),
                (
                  title: '3. Earn access',
                  text: 'Approved contributions unlock learning access under Qaabil’s access rules.',
                ),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(step.title, style: AppTextStyles.title),
                        const SizedBox(height: AppSpacing.sm),
                        Text(step.text, style: AppTextStyles.body),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'Video submissions and member access are coming to the app.',
                style: AppTextStyles.body,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
