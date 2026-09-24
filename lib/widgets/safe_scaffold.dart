import 'package:flutter/material.dart';
import '../utils/responsive.dart';

/// پدینگ امن پایین برای اسکرول‌ها: همیشه فاصله طراحی + inset واقعی
/// نویگیشن سیستم (دکمه‌ای/ژستی/شفاف). بدون این، آخرین دکمه زیر
/// نوار ناوبری گوشی‌های دکمه‌ای می‌رود (edge-to-edge در اندروید ۱۵).
EdgeInsets bottomSafePadding(BuildContext context, {double base = 16, double extra = 8}) {
  final bottom = MediaQuery.viewPaddingOf(context).bottom;
  return EdgeInsets.only(
    left: base,
    right: base,
    top: base,
    bottom: Responsive.bottomSafe(bottom, extra: base + extra),
  );
}

/// فقط قسمت پایین امن (وقتی padding افقی جدا تنظیم شده).
double bottomSafeOnly(BuildContext context, {double extra = 16}) {
  return Responsive.bottomSafe(
    MediaQuery.viewPaddingOf(context).bottom,
    extra: extra,
  );
}

/// بالای صفحه بدون AppBar (مثلاً هدرهای تمام‌عرض داخل بدنه).
double topSafeOnly(BuildContext context, {double extra = 16}) {
  return Responsive.topSafe(
    MediaQuery.viewPaddingOf(context).top,
    extra: extra,
  );
}
