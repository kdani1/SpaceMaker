import 'package:flutter/material.dart';

class SM {
  static const ink = Color(0xFF0E1116);
  static const panel = Color(0xFF171B22);
  static const line = Color(0xFF2A303A);
  static const cream = Color(0xFFF4F1EA);
  static const muted = Color(0xFFC9B896);
  static const keep = Color(0xFF7C9A82);
  static const toss = Color(0xFFC45C3E);
  static const text = Color(0xFFD7D2C8);

  static const title = TextStyle(
    color: cream,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.4,
    height: 1.15,
  );
  static const display = TextStyle(
    color: cream,
    fontSize: 34,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.2,
    height: 1.05,
  );
  static const body = TextStyle(color: text, fontSize: 14, height: 1.45);
  static const caption = TextStyle(color: text, fontSize: 12, height: 1.4);
  static const eyebrow = TextStyle(
    color: muted,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.6,
  );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: ink,
        colorScheme: const ColorScheme.dark(
          primary: muted,
          secondary: keep,
          surface: panel,
          error: toss,
        ),
        textTheme: const TextTheme(
          displayLarge: display,
          headlineMedium: title,
          bodyLarge: body,
          bodyMedium: caption,
          labelLarge: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          foregroundColor: cream,
          titleTextStyle: TextStyle(
            color: cream,
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: panel,
          contentTextStyle: TextStyle(color: cream, fontSize: 14),
        ),
        dividerColor: line,
      );
}
