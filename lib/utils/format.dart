// ابزارهای مشترک قالب‌بندی و اعتبارسنجی.
//
// - ارقام فارسی/عربی به انگلیسی نرمال می‌شوند تا ولیدیشن موبایل و مبلغ درست کار کند.
// - فرمت تومان با جداکننده هزارگان.

/// تبدیل ارقام فارسی (۰۱۲۳۴۵۶۷۸۹) و عربی (٠١٢٣٤٥٦٧٨٩) به انگلیسی + حذف جداکننده‌ها.
String normalizeDigits(String input) {
  const fa = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
  const ar = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  var out = input;
  for (var i = 0; i < 10; i++) {
    out = out.replaceAll(fa[i], '$i').replaceAll(ar[i], '$i');
  }
  // حذف فاصله، کاما، خط‌تیره و ... برای مقایسه عددی
  out = out.replaceAll(RegExp(r'[,\s٬٫_]'), '');
  return out;
}

/// فرمت عدد به تومان: 450000 -> "450,000 تومان"
String formatToman(int value) {
  final s = value.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (m) => ',',
  );
  return '$s تومان';
}

/// شماره موبایل ایران معتبر است؟ (09xxxxxxxxx با ارقام فارسی/عربی هم قبول)
bool isValidIranMobile(String input) {
  final n = normalizeDigits(input.trim());
  return RegExp(r'^09\d{9}$').hasMatch(n);
}

/// پارس مبلغ تومانی از ورودی کاربر (برمی‌گرداند null اگر نامعتبر).
/// قبول می‌کند: "450000"، "450,000"، "۴۵۰٬۰۰۰"
int? parsePrice(String input, {int min = 1000, int max = 1000000000}) {
  final n = normalizeDigits(input.trim());
  final v = int.tryParse(n);
  if (v == null) return null;
  if (v < min || v > max) return null;
  return v;
}

/// پارس امن عدد صحیح از dynamic (برای decode سفارش‌های قدیمی/خراب).
int parseIntSafe(dynamic v, [int fallback = 0]) {
  if (v == null) return fallback;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(normalizeDigits('$v')) ?? fallback;
}

/// کد پیگیری کوتاه مثل QND-8X42K1.
/// [random] برای تست تزریق می‌شود تا خروجی قطعی باشد؛ در محصول از Random امن استفاده کن.
String generateTrackingCode({int Function(int max)? random, DateTime? now}) {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // بدون I,O,0,1 تا اشتباه خوانده نشود
  final r = random ?? _defaultRandom;
  final t = now ?? DateTime.now();
  final buf = StringBuffer('QND-');
  // ۲ حرف از زمان برای یکتایی تقریبی + ۴ کاراکتر تصادفی
  buf.write(alphabet[t.millisecondsSinceEpoch % alphabet.length]);
  buf.write(alphabet[(t.millisecondsSinceEpoch ~/ 997) % alphabet.length]);
  for (var i = 0; i < 4; i++) {
    buf.write(alphabet[r(alphabet.length)]);
  }
  return buf.toString();
}

int _defaultRandom(int max) =>
    DateTime.now().microsecondsSinceEpoch % max;
