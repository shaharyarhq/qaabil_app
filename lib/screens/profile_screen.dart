import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/member.dart';
import '../auth/member_session.dart';
import '../services/member_api.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_card.dart';
import '../widgets/qaabil_app_bar.dart';
import 'blocked_authors_screen.dart';
import 'member_sign_in_gate.dart';
import 'my_submissions_screen.dart';
import '../widgets/website_links.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.onBrowseCourses});
  final VoidCallback onBrowseCourses;

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final member = session.member;
    if (member == null) {
      return MemberSignInGate(
        title: 'My Profile',
        description: 'Sign in to manage your personal information and see your video submissions.',
        onBrowseCourses: onBrowseCourses,
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
                    leading: const Icon(Icons.block),
                    title: const Text('Blocked authors'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const BlockedAuthorsScreen(),
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
          const SizedBox(height: AppSpacing.sm),
          const WebsiteLinks(),
          Center(
            child: TextButton(
              onPressed: () =>
                  WebsiteLinks.open(context, WebsiteLinks.accountDeletion),
              child: const Text('Request account deletion'),
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
  bool _saving = false, _updatingAvatar = false;
  static const _maxPhotoBytes = 5 * 1024 * 1024;
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
    if (_saving ||
        _updatingAvatar ||
        widget.session.busy ||
        !_form.currentState!.validate()) {
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

  Future<void> _chooseAvatar() async {
    if (_saving || _updatingAvatar || widget.session.busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _updatingAvatar = true;
      _error = null;
    });
    String? cachedPath;
    try {
      final XFile? file;
      final String filename;
      if (Platform.isAndroid) {
        const picker = MethodChannel('qaabil/video_picker');
        final selected = await picker.invokeMapMethod<String, String>(
          'pickPhoto',
          {'maxBytes': _maxPhotoBytes},
        );
        if (selected == null) return;
        cachedPath = selected['path']!;
        filename = selected['name']!;
        file = XFile(cachedPath);
      } else {
        file = await openFile(
          acceptedTypeGroups: const [
            XTypeGroup(
              label: 'Profile photos',
              extensions: ['jpg', 'jpeg', 'png', 'webp'],
              mimeTypes: ['image/jpeg', 'image/png', 'image/webp'],
              uniformTypeIdentifiers: [
                'public.jpeg',
                'public.png',
                'org.webmproject.webp',
              ],
            ),
          ],
        );
        if (file == null) return;
        filename = file.name;
      }

      if (await file.length() > _maxPhotoBytes) {
        throw const ApiException('Choose a photo up to 5 MB.');
      }
      final bytes = await file.readAsBytes();
      if (!mounted || widget.session.member?.id != widget.member.id) return;
      await widget.session.updateAvatar(bytes, filename);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile photo updated.')));
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on PlatformException catch (error) {
      if (mounted) {
        setState(
          () => _error = error.code == 'file_too_large'
              ? 'Choose a photo up to 5 MB.'
              : 'Could not open that photo. Choose another file.',
        );
      }
    } on FileSystemException {
      if (mounted) setState(() => _error = 'Could not read that photo.');
    } finally {
      if (cachedPath != null) {
        try {
          await File(cachedPath).delete();
        } on FileSystemException {
          // Android may have already removed the temporary photo.
        }
      }
      if (mounted) setState(() => _updatingAvatar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final enabled = !_saving && !_updatingAvatar && !widget.session.busy;
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
    final photo = widget.member.avatarUrl;
    final avatar = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 48,
          backgroundColor: palette.elevated,
          foregroundColor: palette.textSecondary,
          foregroundImage: photo == null
              ? null
              : NetworkImage(photo.toString()),
          onForegroundImageError: photo == null ? null : (_, _) {},
          child: const Icon(Icons.person_outline_rounded, size: 44),
        ),
        TextButton(
          onPressed: enabled ? _chooseAvatar : null,
          child: Text(
            _updatingAvatar
                ? 'Updating photo…'
                : photo == null
                ? 'Add profile photo'
                : 'Change profile photo',
          ),
        ),
      ],
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
