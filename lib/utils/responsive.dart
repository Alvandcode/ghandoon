// کمک‌های ریسپانسیو (خالص و تست‌پذیر).
// ایده: اندازه نشان‌ها (لوگو/آدمک) کسری از عرض صفحه باشد ولی بین
// کف و سقف قفل شود تا در گوشی خیلی کوچک ریز و در تبلت غول نشود.

/// اندازه نشان دایره‌ای بر اساس عرض صفحه.
// ignore: avoid_classes_with_only_static_members
class Responsive {
  /// [width] عرض صفحه به پیکسل منطقی.
  static double badge(double width,
      {double min = 110, double max = 190, double ratio = 0.42}) {
    final s = width * ratio;
    if (s < min) return min;
    if (s > max) return max;
    return s;
  }

  /// آیا صفحه کوچک است (گوشی‌های قدیمی/باریک)؟ برای فشرده‌تر کردن فاصله‌ها.
  static bool isNarrow(double width) => width < 360;
}
