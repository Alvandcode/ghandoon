// اعتبارسنجی ورودی محصول (خالص و تست‌پذیر — هم مخزن هم فرم از همین استفاده می‌کنند).

import 'format.dart';

/// دسته‌های مجاز (باید با check جدول products در schema.sql یکی باشد).
const productCategories = ['کیک خونگی', 'کوکی', 'بیسکوییت', 'کیک تولد'];

/// null یعنی معتبر؛ وگرنه پیام خطای فارسی برای نمایش.
/// [priceText] همان متن تایپ‌شده کاربر است (ارقام فارسی هم قبول).
String? validateProductFields({
  required String title,
  required String priceText,
  required String category,
}) {
  if (title.trim().length < 2) return 'اسم محصول حداقل ۲ حرف باشد';
  if (!productCategories.contains(category.trim())) {
    return 'دسته معتبر انتخاب کن';
  }
  if (parsePrice(priceText) == null) {
    return 'قیمت معتبر نیست (بین ۱٬۰۰۰ تا ۱٬۰۰۰٬۰۰۰٬۰۰۰ تومان)';
  }
  return null;
}
