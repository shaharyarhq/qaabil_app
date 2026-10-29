import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';

/// The "Search courses…" box from qaabil.io.
///
/// Shows an ✕ button to clear the text once something has been typed.
class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onClear,
    this.hint = 'Search courses…',
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final radius = AppRadius.controlRadius;

    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search, size: 22),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                icon: const Icon(Icons.close, size: 20),
                color: AppColors.textMuted,
                onPressed: onClear,
              ),
        enabledBorder: AppTheme.inputBorder(AppColors.border, radius: radius),
        focusedBorder: AppTheme.inputBorder(AppColors.navy, radius: radius),
      ),
    );
  }
}
