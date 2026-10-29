import 'package:flutter/material.dart';

import 'screens/login_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const QaabilApp());
}

class QaabilApp extends StatelessWidget {
  const QaabilApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Qaabil',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const LoginScreen(),
    );
  }
}
