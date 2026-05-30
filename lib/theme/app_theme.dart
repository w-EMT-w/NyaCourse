import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData build({
    required Brightness brightness,
    Color seedColor = const Color(0xff22b879),
  }) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );
    final isDark = brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor:
          isDark ? const Color(0xff0d0f12) : const Color(0xfff6f8fb),
      fontFamilyFallback: const [
        'PingFang SC',
        'Microsoft YaHei',
        'Roboto',
      ],
      cardTheme: CardThemeData(
        color: isDark ? const Color(0xff171a1d) : Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      ),
    );
  }
}
