import 'package:flutter/material.dart';

import '../widgets/searchable_select.dart';

class AppAppearance extends InheritedWidget {
  const AppAppearance({
    super.key,
    required this.mode,
    required this.onChanged,
    required super.child,
  });

  final ThemeMode mode;
  final ValueChanged<ThemeMode> onChanged;

  static AppAppearance? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppAppearance>();

  @override
  bool updateShouldNotify(AppAppearance oldWidget) => mode != oldWidget.mode;
}

class AppearanceMenu extends StatelessWidget {
  const AppearanceMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final appearance = AppAppearance.of(context);
    if (appearance == null) return const SizedBox.shrink();
    return SearchableSelect<ThemeMode>(
      label: 'Appearance',
      value: appearance.mode,
      onChanged: (mode) => appearance.onChanged(mode!),
      options: const {
        ThemeMode.system: 'System',
        ThemeMode.light: 'Light',
        ThemeMode.dark: 'Dark',
      },
      child: const SizedBox.square(
        dimension: 48,
        child: Icon(Icons.brightness_6_outlined),
      ),
    );
  }
}
