import 'package:flutter/material.dart';

import '../auth/member.dart';
import '../auth/member_session.dart';
import '../services/member_api.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_card.dart';
import '../widgets/qaabil_app_bar.dart';
import '../theme/app_appearance.dart';
import '../widgets/auth_page_body.dart';
import 'login_screen.dart';
import 'my_submissions_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.onBrowseCourses});
  final VoidCallback onBrowseCourses;

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final member = session.member;
    if (member == null) {
      return Scaffold(
        appBar: AppBar(actions: const [AppearanceMenu()]),
        body: AuthPageBody(
          title: 'My Profile',
          description: 'Sign in to manage your personal information and see your video submissions.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton(
                onPressed: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const LoginScreen())),
                child: const Text('Login to your account'),
              ),
              TextButton(
                onPressed: onBrowseCourses,
                child: const Text('Browse courses'),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      appBar: const QaabilAppBar(showAppearance: true),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screen),
        children: [
          Text(
            'My Profile',
            style: AppTextStyles.heading.copyWith(
              color: AppPalette.of(context).textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          _PersonalInformation(
            key: ValueKey(member.id),
            member: member,
            session: session,
          ),
          const SizedBox(height: AppSpacing.xl),
          AppCard(
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.video_library_outlined),
                    title: const Text('My Video Submissions'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: session.busy
                        ? null
                        : () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const MySubmissionsScreen(),
                            ),
                          ),
                  ),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.logout_rounded),
                    title: Text(session.busy ? 'Signing out…' : 'Sign out'),
                    onTap: session.busy ? null : session.logout,
                  ),
                  if (session.error != null)
                    Text(
                      session.error!,
                      style: TextStyle(color: AppPalette.of(context).error),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonalInformation extends StatefulWidget {
  const _PersonalInformation({
    super.key,
    required this.member,
    required this.session,
  });

  final Member member;
  final MemberSession session;

  @override
  State<_PersonalInformation> createState() => _PersonalInformationState();
}

class _PersonalInformationState extends State<_PersonalInformation> {
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
    if (_saving || widget.session.busy || !_form.currentState!.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.session.updateProfile(_name.text, _school.text);
      final saved = widget.session.member;
      if (!mounted || saved == null || saved.id != widget.member.id) return;
      _name.text = saved.fullName ?? '';
      _school.text = saved.school ?? '';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final enabled = !_saving && !widget.session.busy;
    final fields = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ProfileField(
          label: 'Username',
          child: TextFormField(
            key: ValueKey(widget.member.name),
            initialValue: widget.member.name,
            readOnly: true,
            decoration: const InputDecoration(
              suffixIcon: Icon(Icons.lock_outline, size: 18),
            ),
          ),
        ),
        _ProfileField(
          label: 'Email',
          child: TextFormField(
            key: ValueKey(widget.member.email),
            initialValue: widget.member.email,
            readOnly: true,
            decoration: const InputDecoration(
              suffixIcon: Icon(Icons.lock_outline, size: 18),
            ),
          ),
        ),
        _ProfileField(
          label: 'Full name',
          child: TextFormField(
            controller: _name,
            enabled: enabled,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            validator: _validate,
          ),
        ),
        _ProfileField(
          label: 'School / College / University',
          child: TextFormField(
            controller: _school,
            enabled: enabled,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _save(),
            validator: _validate,
          ),
        ),
      ],
    );
    final avatar = CircleAvatar(
      radius: 48,
      backgroundColor: palette.elevated,
      foregroundColor: palette.textSecondary,
      child: const Icon(Icons.person_outline_rounded, size: 44),
    );

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Personal Information',
                  style: AppTextStyles.title.copyWith(
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Manage your personal information.',
                  style: AppTextStyles.body.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: palette.border),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth < 560) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(child: avatar),
                            const SizedBox(height: AppSpacing.lg),
                            fields,
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: Center(child: avatar)),
                          Expanded(flex: 2, child: fields),
                        ],
                      );
                    },
                  ),
                  if (_error != null) ...[
                    Text(_error!, style: TextStyle(color: palette.error)),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: enabled ? _save : null,
                      style: FilledButton.styleFrom(
                        shape: const StadiumBorder(),
                      ),
                      child: Text(_saving ? 'Updating…' : 'Update'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileField extends StatelessWidget {
  const _ProfileField({required this.label, required this.child});

  final String label;
  final TextFormField child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: AppTextStyles.label.copyWith(
            color: AppPalette.of(context).textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Semantics(label: label, child: child),
      ],
    ),
  );
}
