import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF155E75),
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: const Color(0xFFF4F7FB),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFF4F7FB),
      foregroundColor: Color(0xFF122334),
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
  );

  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF67D5E6),
      brightness: Brightness.dark,
    ),
    scaffoldBackgroundColor: const Color(0xFF101827),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF101827),
      foregroundColor: Colors.white,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
  );
}
