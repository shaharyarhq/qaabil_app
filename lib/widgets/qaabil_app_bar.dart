import 'package:flutter/material.dart';

import 'qaabil_logo.dart';
import '../auth/member_session.dart';
import '../screens/login_screen.dart';

/// Shared header for the app. Flutter adds a back button on pushed pages.
class QaabilAppBar extends StatelessWidget implements PreferredSizeWidget {
  const QaabilAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    return AppBar(
      toolbarHeight: preferredSize.height,
      centerTitle: false,
      titleSpacing: 20,
      title: const QaabilLogo(height: 32),
      actions: [
        if (session.member == null)
          TextButton(
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const LoginScreen())),
            child: const Text('Login'),
          ),
        const SizedBox(width: 8),
      ],
    );
  }
}
