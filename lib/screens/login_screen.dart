import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import '../widgets/app_card.dart';
import '../widgets/labeled_text_field.dart';
import '../widgets/qaabil_logo.dart';
import '../widgets/section_header.dart';
import 'courses_screen.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  void _login(BuildContext context) {
    // No real authentication yet: just go to the courses screen.
    // pushReplacement removes Login from the back stack, so the
    // back button won't return here after "logging in".
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const CoursesScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screen,
              vertical: AppSpacing.xxxl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSpacing.formMaxWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: QaabilLogo(height: 56)),
                  const SizedBox(height: AppSpacing.xxxl + AppSpacing.sm),
                  const SectionHeader(
                    eyebrow: 'Welcome back',
                    title: 'Log in to continue your ',
                    accent: 'learning.',
                    subtitle: 'Sign in to see your IGCSE courses.',
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  AppCard(
                    raised: true,
                    padding: const EdgeInsets.all(AppSpacing.xxl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const LabeledTextField(
                          label: 'Email',
                          hint: 'you@example.com',
                          icon: Icons.mail_outline,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        const LabeledTextField(
                          label: 'Password',
                          hint: 'Your password',
                          icon: Icons.lock_outline,
                          obscureText: true,
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                        FilledButton(
                          onPressed: () => _login(context),
                          child: const Text('Login'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
