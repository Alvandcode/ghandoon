// اعتبارسنجی ورودی محصول (خالص و تست‌پذیر — هم مخزن هم فرم از همین استفاده می‌کنند).

import '../config/app_config.dart';
import 'format.dart';

/// دسته‌های پیش‌فرض (وقتی تنظیمات سرور در دسترس نیست).
/// فهرست واقعی چهار شاخه اصلی از SettingsService می‌آید و مدیر عوضش می‌کند.
const productCategories = AppConfig.defaultMainCategories;

/// null یعنی معتبر؛ وگرنه پیام خطای فارسی برای نمایش.
/// [priceText] همان متن تایپ‌شده کاربر است (ارقام فارسی هم قبول).
/// [allowedCategories] چهار شاخه اصلی فروشگاه؛ خالی = پیش‌فرض.
String? validateProductFields({
  required String title,
  required String priceText,
  required String category,
  List<String> allowedCategories = productCategories,
}) {
  if (title.trim().length < 2) return 'اسم محصول حداقل ۲ حرف باشد';
  final allowed =
      allowedCategories.isEmpty ? productCategories : allowedCategories;
  if (!allowed.contains(category.trim())) {
    return 'دسته معتبر انتخاب کن';
  }
  if (parsePrice(priceText) == null) {
    return 'قیمت معتبر نیست (بین ۱٬۰۰۰ تا ۱٬۰۰۰٬۰۰۰٬۰۰۰ تومان)';
  }
  return null;
}

/// نگاشت دسته‌های قدیمی به شاخه اصلی جدید (برای داده‌های موجود سرور).
/// محصولات جدید مستقیم با دسته اصلی ساخته می‌شوند.
const legacyCategoryToMain = <String, String>{
  'کیک خونگی': 'کیک',
  'کیک تولد': 'کیک',
  'کوکی': 'شیرینی',
  'بیسکوییت': 'شیرینی',
};

/// اگر category محصول یکی از دسته‌های اصلی نبود، نگاشت قدیمی را امتحان کن.
String normalizeProductCategory(String category, List<String> mains) {
  final t = category.trim();
  if (mains.contains(t)) return t;
  final legacy = legacyCategoryToMain[t];
  if (legacy != null && mains.contains(legacy)) return legacy;
  return t;
}

/// آیا محصول با این دسته (قدیمی یا جدید) باید داخل شاخه اصلی [main] نشان داده شود؟
/// فیلتر صفحه لیست محصولات از همین استفاده می‌کند تا محصولاتی که هنوز دسته
/// قدیمی سرور دارند (کوکی/کیک خونگی/بیسکوییت/کیک تولد) زیر شاخه درست بیایند
/// و «هنوز محصولی توی این دسته نیست» نشان ندهند.
bool productInMainCategory(String category, String main) {
  final m = main.trim();
  if (m.isEmpty) return false;
  return normalizeProductCategory(category, [m]) == m;
}
