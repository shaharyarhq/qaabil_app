import 'package:flutter/material.dart';

import '../theme/app_text_styles.dart';
import '../theme/app_tokens.dart';
import 'app_card.dart';
import 'qaabil_logo.dart';

class AuthPageBody extends StatelessWidget {
  const AuthPageBody({
    super.key,
    required this.title,
    required this.child,
    this.description,
  });

  final String title;
  final String? description;
  final Widget child;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screen),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSpacing.formMaxWidth),
          child: AppCard(
            raised: true,
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: QaabilLogo(height: 44)),
                const SizedBox(height: AppSpacing.lg),
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.heading.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                if (description case final description?) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(description, textAlign: TextAlign.center),
                ],
                const SizedBox(height: AppSpacing.xxl),
                child,
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
