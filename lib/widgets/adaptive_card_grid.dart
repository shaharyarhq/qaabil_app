import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Keeps cards readable as a page grows from a phone to a wide screen.
class AdaptiveCardGrid extends StatelessWidget {
  const AdaptiveCardGrid({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const gap = AppSpacing.lg;
      final maxColumns = children.length.clamp(1, 4);
      final columns = ((constraints.maxWidth + gap) / 310).floor().clamp(
        1,
        maxColumns,
      );
      final width = (constraints.maxWidth - gap * (columns - 1)) / columns;

      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final card in children) SizedBox(width: width, child: card),
        ],
      );
    },
  );
}
