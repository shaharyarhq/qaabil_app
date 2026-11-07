import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

/// A tactile primary action that keeps Material's keyboard and accessibility support.
class PrimaryButton extends StatefulWidget {
  const PrimaryButton({
    super.key,
    required this.onPressed,
    required this.child,
  });
  final VoidCallback? onPressed;
  final Widget child;
  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool _pressed = false;
  void _press(bool value) {
    if (mounted && _pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Listener(
      onPointerDown: (_) {
        if (widget.onPressed != null) _press(true);
      },
      onPointerUp: (_) => _press(false),
      onPointerCancel: (_) => _press(false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        transform: Matrix4.translationValues(0, _pressed ? 4 : 0, 0),
        decoration: BoxDecoration(
          borderRadius: AppRadius.button,
          boxShadow: _pressed
              ? []
              : [
                  BoxShadow(
                    color: widget.onPressed == null
                        ? AppColors.border
                        : AppColors.navyDark,
                    offset: const Offset(0, 5),
                    blurRadius: 0,
                  ),
                ],
        ),
        child: FilledButton(onPressed: widget.onPressed, child: widget.child),
      ),
    ),
  );
}
