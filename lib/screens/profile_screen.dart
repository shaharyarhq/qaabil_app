import 'package:flutter/material.dart';

import '../auth/member.dart';
import '../auth/member_session.dart';
import '../services/member_api.dart';
import '../widgets/primary_button.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_card.dart';
import '../widgets/qaabil_app_bar.dart';
import 'member_area_screen.dart';
import 'my_submissions_screen.dart';

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
                    const SizedBox(height: AppSpacing.lg),
                    const Text('Full name', style: AppTextStyles.label),
                    Text(
                      member.fullName ?? 'Not added',
                      style: AppTextStyles.body,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Text(
                      'School / College / University',
                      style: AppTextStyles.label,
                    ),
                    Text(
                      member.school ?? 'Not added',
                      style: AppTextStyles.body,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    PrimaryButton(
                      onPressed: session.busy
                          ? null
                          : () async {
                              final saved = await showDialog<bool>(
                                context: context,
                                barrierDismissible: false,
                                builder: (_) => _EditProfileDialog(
                                  member: member,
                                  session: session,
                                ),
                              );
                              if (saved == true && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Profile saved'),
                                  ),
                                );
                              }
                            },
                      child: const Text('Edit profile'),
                    ),
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
              AppCard(
                child: Material(
                  color: Colors.transparent,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.video_library_outlined,
                      color: AppColors.violet,
                    ),
                    title: const Text(
                      'My Video Submissions',
                      style: AppTextStyles.title,
                    ),
                    subtitle: const Text(
                      'Follow the review status of your videos.',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const MySubmissionsScreen(),
                      ),
                    ),
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

class _EditProfileDialog extends StatefulWidget {
  const _EditProfileDialog({required this.member, required this.session});

  final Member member;
  final MemberSession session;

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  late final _name = TextEditingController(text: widget.member.fullName);
  late final _school = TextEditingController(text: widget.member.school);
  final _form = GlobalKey<FormState>();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _school.dispose();
    super.dispose();
  }

  String? _validate(String? value) => (value ?? '').trim().runes.length > 120
      ? 'Use 120 characters or fewer.'
      : null;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (widget.session.member?.id != widget.member.id) {
      setState(() => _error = 'Sign in again to edit your profile.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.session.updateProfile(_name.text, _school.text);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      scrollable: true,
      title: const Text('Edit profile'),
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _name,
              enabled: !_saving,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Full name'),
              validator: _validate,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _school,
              enabled: !_saving,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'School / College / University',
              ),
              validator: _validate,
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Save profile'),
        ),
      ],
    ),
  );
}
