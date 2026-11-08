import 'dart:convert';

import 'package:flutter/material.dart';

import '../auth/member_session.dart';
import '../services/member_api.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_card.dart';
import '../widgets/primary_button.dart';

class PasswordResetScreen extends StatefulWidget {
  const PasswordResetScreen({super.key, required this.email});

  final String email;

  @override
  State<PasswordResetScreen> createState() => _PasswordResetScreenState();
}

class _PasswordResetScreenState extends State<PasswordResetScreen> {
  final _form = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.email);
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _requested = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    final api = SessionScope.of(context).api;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_requested) {
        await api.resetPassword(
          _email.text.trim(),
          _code.text.trim(),
          _password.text,
          _confirmation.text,
        );
        if (mounted) Navigator.of(context).pop(true);
      } else {
        await api.requestPasswordReset(_email.text.trim());
        if (mounted) setState(() => _requested = true);
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('Reset password')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.screen),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSpacing.formMaxWidth,
              ),
              child: AppCard(
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _requested
                            ? 'If this email belongs to a member, a reset code will arrive shortly. Copy it from the email and paste it below.'
                            : 'Enter the email for your Qaabil member account.',
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      TextFormField(
                        controller: _email,
                        enabled: !_busy && !_requested,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(labelText: 'Email'),
                        validator: (value) =>
                            RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                .hasMatch(value?.trim() ?? '')
                            ? null
                            : 'Enter a valid email.',
                      ),
                      if (_requested) ...[
                        const SizedBox(height: AppSpacing.md),
                        TextFormField(
                          controller: _code,
                          enabled: !_busy,
                          autocorrect: false,
                          enableSuggestions: false,
                          decoration: const InputDecoration(
                            labelText: 'Reset code',
                          ),
                          validator: (value) =>
                              RegExp(r'^[a-f0-9]{64}$')
                                  .hasMatch(value?.trim() ?? '')
                              ? null
                              : 'Paste the full code from your email.',
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextFormField(
                          controller: _password,
                          enabled: !_busy,
                          obscureText: true,
                          autocorrect: false,
                          enableSuggestions: false,
                          autofillHints: const [AutofillHints.newPassword],
                          decoration: const InputDecoration(
                            labelText: 'New password',
                          ),
                          validator: (value) {
                            final password = value ?? '';
                            if (password.runes.length < 8) {
                              return 'Use at least 8 characters.';
                            }
                            if (utf8.encode(password).length > 72) {
                              return 'Use a shorter password.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextFormField(
                          controller: _confirmation,
                          enabled: !_busy,
                          obscureText: true,
                          autocorrect: false,
                          enableSuggestions: false,
                          decoration: const InputDecoration(
                            labelText: 'Confirm new password',
                          ),
                          validator: (value) => value == _password.text
                              ? null
                              : 'Passwords must match.',
                        ),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      PrimaryButton(
                        onPressed: _busy ? null : _submit,
                        child: Text(
                          _busy
                              ? (_requested ? 'Saving…' : 'Requesting…')
                              : (_requested
                                    ? 'Change password'
                                    : 'Send reset code'),
                        ),
                      ),
                      if (_requested)
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => setState(() {
                                  _requested = false;
                                  _error = null;
                                  _code.clear();
                                  _password.clear();
                                  _confirmation.clear();
                                }),
                          child: const Text('Request another code'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
