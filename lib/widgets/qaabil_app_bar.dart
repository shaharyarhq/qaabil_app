import 'package:flutter/material.dart';

import 'qaabil_logo.dart';
import '../theme/app_appearance.dart';
import '../auth/member_session.dart';
import '../screens/login_screen.dart';

/// Shared header for the app. Flutter adds a back button on pushed pages.
class QaabilAppBar extends StatelessWidget implements PreferredSizeWidget {
  const QaabilAppBar({
    super.key,
    this.height = 64,
    this.logoHeight = 32,
    this.showAppearance = false,
  });

  final double height;
  final double logoHeight;
  final bool showAppearance;

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    return AppBar(
      toolbarHeight: preferredSize.height,
      centerTitle: false,
      titleSpacing: 20,
      title: QaabilLogo(height: logoHeight),
      actions: [
        if (showAppearance) const AppearanceMenu(),
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
