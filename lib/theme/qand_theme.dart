import 'package:flutter/material.dart';

/// تم وینتیج قندون:
/// - قرمز ساده برند (#F02010 از دل لوگو) — بدون گرادیان مدرن.
/// - تیتر بهمن، متن کتیبه (نسخ)، ذخیره لاله‌زار/وزیرمتن.
class QandTheme {
  /// قرمز برند — استخراج‌شده از لوگو.
  static const Color red = Color(0xFFF02010);
  static const Color redDark = Color(0xFFB3120A);
  static const Color cream = Color(0xFFFBF0DC);
  static const Color creamDark = Color(0xFFF0D9B5);
  static const Color ink = Color(0xFF3A2222);

  static const String titleFont = 'Bahman';
  static const String bodyFont = 'Katibeh';
  static const String fallbackFont = 'Vazirmatn';

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: red,
      primary: red,
      secondary: const Color(0xFFB3120A),
      surface: Colors.white,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: cream,
      fontFamily: bodyFont,
      fontFamilyFallback: const ['Lalezar', fallbackFont],
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontFamily: titleFont, fontSize: 34),
        displayMedium: TextStyle(fontFamily: titleFont, fontSize: 28),
        displaySmall: TextStyle(fontFamily: titleFont, fontSize: 24),
        headlineMedium: TextStyle(fontFamily: titleFont, fontSize: 22),
        headlineSmall: TextStyle(fontFamily: titleFont, fontSize: 20),
        titleLarge: TextStyle(fontFamily: titleFont, fontSize: 18),
      ),
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
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: redDark, width: 2),
          ),
          textStyle: const TextStyle(
              fontSize: 18, fontFamily: titleFont),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      cardTheme: const CardThemeData(
        elevation: 4,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
          side: BorderSide(color: creamDark),
        ),
      ),
      chipTheme: const ChipThemeData(
        selectedColor: red,
        secondarySelectedColor: red,
        backgroundColor: Colors.white,
        // دکمه انتخاب‌نشده: پس‌زمینه روشن → متن تیره (وگرنه سفید روی سفید می‌شود!)
        labelStyle: TextStyle(color: ink),
        // دکمه انتخاب‌شده: پس‌زمینه قرمز → متن سفید
        secondaryLabelStyle: TextStyle(color: Colors.white),
        checkmarkColor: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12))),
      ),
    );
  }

  /// هدر قرمز ساده برند (وینتیج = فلت، بدون گرادیان).
  /// اسم متد عوض نشده تا همه صفحه‌ها دست‌نخورده بمانند.
  static BoxDecoration headerGradient({double radius = 36}) {
    return BoxDecoration(
      color: red,
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(radius)),
    );
  }
}
