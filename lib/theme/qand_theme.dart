import 'package:flutter/material.dart';

class QandTheme {
  static const Color red = Color(0xFFD62828);
  static const Color redDark = Color(0xFFA81E1E);
  static const Color cream = Color(0xFFFFF3E4);
  static const Color creamDark = Color(0xFFF5D9B8);
  static const Color ink = Color(0xFF3A2A2A);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: red,
      primary: red,
      secondary: const Color(0xFFFF8A5C),
      surface: Colors.white,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFFFFFBF5),
      fontFamily: 'Vazirmatn',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: Colors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: red,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      cardTheme: CardThemeData(
        elevation: 6,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
    );
  }

  static BoxDecoration headerGradient({double radius = 36}) {
    return BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        // بالا نارنجی → پایین قرمز
        colors: [Color(0xFFFF8A5C), Color(0xFFE63946), Color(0xFFD62828)],
      ),
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(radius)),
    );
  }
}
