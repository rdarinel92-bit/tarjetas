import 'package:flutter/material.dart';

class PremiumTheme {
  static const Color backgroundDark = Color(0xFF020617);
  static const Color cardColor = Colors.white24;
  static const Color accent = Colors.blueAccent;
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Colors.white70;

  static ThemeData darkTheme() {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: backgroundDark,
      primaryColor: accent,
      colorScheme: const ColorScheme.dark(
        primary: Colors.blueAccent,
        secondary: Colors.cyanAccent,
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(fontFamily: 'Roboto', fontSize: 16),
        titleLarge: TextStyle(fontFamily: 'Roboto', fontSize: 28),
      ),
      useMaterial3: true,
    );
  }
}
