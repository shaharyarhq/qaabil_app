import 'package:flutter/material.dart';

/// The Qaabil logo from qaabil.io ("QAABIL — Empowering Learning!").
class QaabilLogo extends StatelessWidget {
  const QaabilLogo({super.key, this.height = 48});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/qaabil_logo.png',
      height: height,
      semanticLabel: 'Qaabil',
    );
  }
}
