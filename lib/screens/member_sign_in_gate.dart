import 'package:flutter/material.dart';

import '../theme/app_appearance.dart';
import '../widgets/auth_page_body.dart';
import 'login_screen.dart';

class MemberSignInGate extends StatelessWidget {
  const MemberSignInGate({
    super.key,
    required this.title,
    required this.description,
    required this.onBrowseCourses,
  });

  final String title;
  final String description;
  final VoidCallback onBrowseCourses;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(actions: const [AppearanceMenu()]),
    body: AuthPageBody(
      title: title,
      description: description,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton(
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const LoginScreen())),
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
