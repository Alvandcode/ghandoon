// قوانین کسب‌وکاری سفارش قنادی (خالص و تست‌پذیر).
// بدون وابستگی به فلاتر تا در CI آفلاین هم تست شود.

/// حداقل روزهای لازم برای آماده‌سازی بر اساس محصول.
/// کیک تولد سفارشی حداقل ۳ روز، کیک خونگی ۲ روز، بقیه ۱ روز.
/// [productId] شناسه دمو (homemade/cookie/biscuit/birthday) یا هر رشته؛
/// [category] دسته فارسی. هر کدام که بخورد، بیشترین مقدار برمی‌گردد.
int minLeadDaysForProduct({required String productId, required String category}) {
  final id = productId.trim().toLowerCase();
  final cat = category.trim();
  if (id == 'birthday' || cat == 'کیک تولد') return 3;
  if (id == 'homemade' || cat == 'کیک خونگی') return 2;
  return 1;
}

/// اولین تاریخ مجاز سفارش (بدون ساعت) = امروز + حداقل lead.
/// [today] برای تست تزریق می‌شود.
DateTime minOrderDate({
  required String productId,
  required String category,
  DateTime? today,
}) {
  final now = today ?? DateTime.now();
  final t = DateTime(now.year, now.month, now.day);
  return t.add(Duration(days: minLeadDaysForProduct(productId: productId, category: category)));
}

/// آیا تاریخ انتخابی برای این محصول مجاز است؟ (مقایسه بدون ساعت)
bool isOrderDateAllowed({
  required DateTime picked,
  required String productId,
  required String category,
  DateTime? today,
}) {
  final p = DateTime(picked.year, picked.month, picked.day);
  return !p.isBefore(
      minOrderDate(productId: productId, category: category, today: today));
}

// ---------------- کیک‌ساز سفارشی ----------------

/// وزن‌های قابل سفارش (کیلوگرم).
const customCakeWeights = [1.0, 1.5, 2.0, 3.0, 4.0, 5.0];

/// طعم‌های کیک.
const customCakeFlavors = [
  'وانیلی',
  'شکلاتی',
  'نسکافه‌ای',
  'ردولوت',
  'لیمویی',
  'هویج و گردو',
];

/// فیلینگ‌ها.
const customCakeFillings = [
  'خامه وانیلی',
  'گاناش شکلات',
  'نوتلا',
  'کارامل',
  'میوه فصل',
  'پنیر خامه‌ای',
];

/// قیمت پایه هر کیلو (تومان). قیمت نهایی = وزن × این عدد.
/// در پنل بعدی می‌تواند از سرور بیاید؛ فعلاً ثابت قابل‌تست.
const customCakePricePerKg = 380000;

/// قیمت کیک سفارشی از روی وزن. وزن نامعتبر → null.
int? customCakePrice(double weightKg) {
  if (!customCakeWeights.contains(weightKg)) return null;
  return (weightKg * customCakePricePerKg).round();
}

/// خلاصه مشخصات کیک برای فاکتور و سبد.
String customCakeOptionsSummary({
  required double weightKg,
  required String flavor,
  required String filling,
  String cakeText = '',
}) {
  final w = weightKg.toString().replaceAll('.0', '');
  final t = cakeText.trim();
  final base = 'کیک $w کیلویی $flavor با فیلینگ $filling';
  return t.isEmpty ? base : '$base | متن: $t';
}

// ---------------- هزینه ارسال ----------------

/// آستانه ارسال رایگان و مبلغ پایه پیک (تومان) — قابل تنظیم.
const freeDeliveryThreshold = 1000000;
const baseDeliveryFee = 45000;

/// هزینه پیک: حضوری همیشه ۰؛ ارسال با جمع بالای آستانه رایگان.
int deliveryFee({required bool pickup, required int itemsTotal}) {
  if (pickup) return 0;
  if (itemsTotal >= freeDeliveryThreshold) return 0;
  return baseDeliveryFee;
}

// ---------------- سبد خرید ----------------

/// lead سبد = بیشترین lead اقلام (لیست خالی → ۱).
int cartLeadDays(List<int> leads) {
  var max = 1;
  for (final l in leads) {
    if (l > max) max = l;
  }
  return max;
}

/// اولین تاریخ مجاز برای سبدی با lead مشخص.
DateTime minCartDate({required int leadDays, DateTime? today}) {
  final now = today ?? DateTime.now();
  final t = DateTime(now.year, now.month, now.day);
  return t.add(Duration(days: leadDays < 1 ? 1 : leadDays));
}
