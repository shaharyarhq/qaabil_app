import 'package:flutter/material.dart';
import 'package:qaabil_mobile/widgets/primary_button.dart';

import '../auth/member_session.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_card.dart';
import '../widgets/qaabil_app_bar.dart';
import 'get_access_screen.dart';
import 'login_screen.dart';

/// Public introduction to a member area, until authentication is connected.
class MemberAreaScreen extends StatelessWidget {
  const MemberAreaScreen({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.features,
    this.onBrowseCourses,
  });

  final String title;
  final String description;
  final IconData icon;
  final List<({IconData icon, String title, String description})> features;
  final VoidCallback? onBrowseCourses;

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final member = session.member;
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
              Text('MEMBER SPACE', style: AppTextStyles.eyebrow),
              const SizedBox(height: AppSpacing.sm),
              Text(title, style: AppTextStyles.heading),
              const SizedBox(height: AppSpacing.sm),
              Text(description, style: AppTextStyles.body),
              const SizedBox(height: AppSpacing.xxl),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: CircleAvatar(
                        radius: 28,
                        backgroundColor: AppColors.navyTint,
                        child: Icon(icon, color: AppColors.navy, size: 28),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      member == null
                          ? 'Make room for your progress'
                          : 'Welcome, ${member.name}',
                      style: AppTextStyles.title,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const Text(
                      'Browse courses freely. Your member account will bring your learning together here.',
                      style: AppTextStyles.body,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (member == null)
                      PrimaryButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                        ),
                        child: const Text('Login to your account'),
                      ),
                    if (onBrowseCourses != null)
                      TextButton(
                        onPressed: onBrowseCourses,
                        child: const Text('Browse courses'),
                      ),
                    const SizedBox(height: AppSpacing.sm),
                    const Text(
                      'These member features are being connected.',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              const Text(
                'With your member account',
                style: AppTextStyles.title,
              ),
              const SizedBox(height: AppSpacing.md),
              for (final feature in features)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: AppCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(feature.icon, color: AppColors.navy),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(feature.title, style: AppTextStyles.label),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                feature.description,
                                style: AppTextStyles.body,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              TextButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const GetAccessScreen()),
                ),
                icon: const Icon(Icons.lock_open_outlined),
                label: const Text('How access works'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
