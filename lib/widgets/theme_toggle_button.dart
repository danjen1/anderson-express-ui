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
        final bg = dark ? const Color(0xFF2C2C2C) : const Color(0xFFA8D6F7);
        final fg = dark ? const Color(0xFFE4E4E4) : const Color(0xFF296273);
        final border = dark ? const Color(0xFFB39CD0) : const Color(0xFF442E6F);
        return Tooltip(
          message: dark ? 'Switch to light mode' : 'Switch to dark mode',
          child: Material(
            color: bg,
            shape: StadiumBorder(side: BorderSide(color: border)),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: ThemeController.toggle,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      dark ? Icons.wb_sunny_rounded : Icons.dark_mode_rounded,
                      size: 18,
                      color: fg,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      dark ? 'Light' : 'Dark',
                      style: TextStyle(
                        color: fg,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
