import 'package:flutter/material.dart';

import '../auth/member_session.dart';
import '../theme/app_tokens.dart';
import '../theme/app_appearance.dart';
import '../widgets/auth_page_body.dart';
import 'password_reset_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _hidePassword = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final success = await SessionScope.of(context)
        .login(_email.text.trim(), _password.text);
    if (mounted && success) Navigator.of(context).pop();
  }

  Future<void> _openPasswordReset() async {
    FocusScope.of(context).unfocus();
    final reset = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PasswordResetScreen(email: _email.text.trim()),
      ),
    );
    if (mounted && reset == true) {
      _password.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password changed. Sign in with your new password.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    return Scaffold(
      appBar: AppBar(actions: const [AppearanceMenu()]),
      body: AuthPageBody(
        title: 'Member Login',
        child: Form(
          key: _form,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _email,
                  enabled: !session.busy,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.username],
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  decoration: const InputDecoration(labelText: 'Email address'),
                  validator: (value) {
                    final email = value?.trim() ?? '';
                    if (email.isEmpty) return 'Enter your email.';
                    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                        .hasMatch(email)) {
                      return 'Enter a valid email.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: session.busy || !session.api.configured
                        ? null
                        : _openPasswordReset,
                    child: const Text('Forgot password?'),
                  ),
                ),
                TextFormField(
                  controller: _password,
                  enabled: !session.busy,
                  obscureText: _hidePassword,
                  enableSuggestions: false,
                  autocorrect: false,
                  autofillHints: const [AutofillHints.password],
                  onFieldSubmitted: (_) {
                    if (!session.busy) _login();
                  },
                  decoration: InputDecoration(
                    labelText: 'Password',
                    suffixIcon: IconButton(
                      tooltip: _hidePassword
                          ? 'Show password'
                          : 'Hide password',
                      onPressed: () =>
                          setState(() => _hidePassword = !_hidePassword),
                      icon: Icon(
                        _hidePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Enter your password.'
                      : null,
                ),
                if (session.error != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    session.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                if (!session.api.configured) ...[
                  const SizedBox(height: AppSpacing.md),
                  const Text(
                    'Member sign-in is not available in this build yet.',
                  ),
                ],
                const SizedBox(height: AppSpacing.xxl),
                FilledButton(
                  onPressed: session.busy ? null : _login,
                  child: session.busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Sign in'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
