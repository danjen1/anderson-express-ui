import 'package:flutter/material.dart';

import '../services/theme_controller.dart';

class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.listenable,
      builder: (context, mode, _) {
        final dark = mode == ThemeMode.dark;
        return IconButton(
          tooltip: dark ? 'Switch to light mode' : 'Switch to dark mode',
          onPressed: ThemeController.toggle,
          icon: Icon(dark ? Icons.wb_sunny_outlined : Icons.dark_mode_outlined),
        );
      },
    );
  }
}
