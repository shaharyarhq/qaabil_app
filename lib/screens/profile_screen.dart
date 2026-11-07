import 'package:flutter/material.dart';

import '../auth/member_session.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_card.dart';
import '../widgets/qaabil_app_bar.dart';
import 'member_area_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.onBrowseCourses});
  final VoidCallback onBrowseCourses;

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final member = session.member;
    if (member == null) {
      return MemberAreaScreen(
        title: 'Your profile',
        description: 'Your account and your place in the Qaabil community.',
        icon: Icons.person_outline,
        onBrowseCourses: onBrowseCourses,
        features: const [
          (
            icon: Icons.person_outline,
            title: 'Personal information',
            description: 'Your name, email and school details.',
          ),
          (
            icon: Icons.video_library_outlined,
            title: 'My video submissions',
            description: 'Follow the review status of your contributions.',
          ),
          (
            icon: Icons.badge_outlined,
            title: 'Member ID and certificates',
            description: 'Your member identity and earned certificates.',
          ),
        ],
      );
    }
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
              const Text('Your profile', style: AppTextStyles.heading),
              const SizedBox(height: AppSpacing.xl),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.amberTint,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: AppColors.amber,
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.person_rounded,
                            color: AppColors.navy,
                            size: 38,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(
                          child: Text(
                            member.name,
                            style: AppTextStyles.cardTitle,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(member.email, style: AppTextStyles.body),
                    if (member.fullName?.isNotEmpty ?? false)
                      Text(member.fullName!, style: AppTextStyles.body),
                    if (member.school?.isNotEmpty ?? false)
                      Text(member.school!, style: AppTextStyles.body),
                    const SizedBox(height: AppSpacing.xl),
                    if (session.error != null)
                      Text(
                        session.error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    OutlinedButton(
                      onPressed: session.busy ? null : () => session.logout(),
                      child: Text(session.busy ? 'Signing out…' : 'Sign out'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const Text(
                'Profile editing will be connected next.',
                style: AppTextStyles.body,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
