// متن‌های قابل‌ویرایش اپ.
//
// هدف: مدیر بتواند همه متن‌های صفحه‌های اصلی (خانه، کیک‌ساز سفارشی) را
// بدون تغییر کد عوض کند. هر متن یک «کلید» ثابت دارد و مقدارش از تنظیمات
// (Supabase + آینه لوکال) می‌آید؛ اگر چیزی ذخیره نشده باشد، مقدار
// پیش‌فرض زیر استفاده می‌شود تا اپ هیچ‌وقت متن خالی نشان ندهد.
//
// الگو: در UI بنویس  AppTexts.of(context).t('cake.weight_title')
// و در پنل مدیر، هر کلید از همین جدول خودکار ساخته می‌شود.

import 'package:flutter/material.dart';

/// یک متن قابل ویرایش: کلید فنی + برچسب فارسی برای پنل مدیر + مقدار پیش‌فرض.
class AppTextEntry {
  /// کلید فنی (در کد و ذخیره‌سازی استفاده می‌شود).
  final String key;
  /// عنوانی که مدیر در پنل می‌بیند.
  final String label;
  /// متن پیش‌فرض (همان چیزی که قبلاً داخل کد هاردکد بود).
  final String defaultValue;
  /// گروه نمایشی در پنل مدیر.
  final String group;
  /// اگر متن نباید خالی شود (مثل دکمه اصلی) — نادیده‌اش می‌گیریم
  /// و مقدار پیش‌فرض را نگه می‌داریم.
  final bool required;

  const AppTextEntry({
    required this.key,
    required this.label,
    required this.defaultValue,
    required this.group,
    this.required = false,
  });
}

/// همه متن‌های قابل ویرایش در یک جا.
/// ⚠️ این فهرست را با هر متن هاردکدِ جدیدِ صفحه‌های خانه/کیک‌ساز به‌روز کن.
const List<AppTextEntry> appTextEntries = [
  // ---------------- صفحه خانه ----------------
  AppTextEntry(
    key: 'home.greeting',
    label: 'خانه — سلام (نام کاربر بعدش می‌آید)',
    defaultValue: 'سلام',
    group: 'صفحه خانه',
    required: true,
  ),
  AppTextEntry(
    key: 'home.headline',
    label: 'خانه — تیتر اصلی',
    defaultValue: 'امروز چی برات بپزم؟',
    group: 'صفحه خانه',
    required: true,
  ),
  AppTextEntry(
    key: 'home.cart_tooltip',
    label: 'خانه — راهنمای دکمه سبد',
    defaultValue: 'سبد خرید',
    group: 'صفحه خانه',
  ),
  AppTextEntry(
    key: 'home.notifications_tooltip',
    label: 'خانه — راهنمای دکمه اعلان',
    defaultValue: 'پیگیری سفارش‌ها',
    group: 'صفحه خانه',
  ),
  AppTextEntry(
    key: 'home.custom_cake_button',
    label: 'خانه — دکمه کیک تولد سفارشی',
    defaultValue: 'کیک تولد سفارشی بساز 🎂',
    group: 'صفحه خانه',
    required: true,
  ),
  AppTextEntry(
    key: 'home.no_branches',
    label: 'خانه — وقتی هیچ شاخه‌ای نیست',
    defaultValue: 'هنوز شاخه‌ای ثبت نشده 🍰',
    group: 'صفحه خانه',
  ),
  AppTextEntry(
    key: 'home.no_products',
    label: 'خانه — وقتی فروشگاه خالی است',
    defaultValue: '🛒 فعلاً محصولی برای فروش فعال نیست؛ بعداً سر بزن.',
    group: 'صفحه خانه',
  ),

  // ---------------- کیک تولد سفارشی ----------------
  AppTextEntry(
    key: 'cake.title',
    label: 'کیک‌ساز — عنوان صفحه',
    defaultValue: 'کیک تولد سفارشی 🎂',
    group: 'کیک تولد سفارشی',
    required: true,
  ),
  AppTextEntry(
    key: 'cake.cart_item_title',
    label: 'کیک‌ساز — عنوان محصول در سبد',
    defaultValue: 'کیک تولد سفارشی',
    group: 'کیک تولد سفارشی',
    required: true,
  ),
  AppTextEntry(
    key: 'cake.weight_title',
    label: 'کیک‌ساز — عنوان بخش وزن',
    defaultValue: 'وزن کیک',
    group: 'کیک تولد سفارشی',
    required: true,
  ),
  AppTextEntry(
    key: 'cake.weight_unit',
    label: 'کیک‌ساز — واحد وزن (کنار عدد)',
    defaultValue: 'کیلو',
    group: 'کیک تولد سفارشی',
    required: true,
  ),
  AppTextEntry(
    key: 'cake.flavor_title',
    label: 'کیک‌ساز — عنوان بخش طعم',
    defaultValue: 'طعم کیک',
    group: 'کیک تولد سفارشی',
    required: true,
  ),
  AppTextEntry(
    key: 'cake.filling_title',
    label: 'کیک‌ساز — عنوان بخش فیلینگ',
    defaultValue: 'فیلینگ',
    group: 'کیک تولد سفارشی',
    required: true,
  ),
  AppTextEntry(
    key: 'cake.text_label',
    label: 'کیک‌ساز — برچسب «متن روی کیک»',
    defaultValue: 'متن روی کیک (اختیاری)',
    group: 'کیک تولد سفارشی',
    required: true,
  ),
  AppTextEntry(
    key: 'cake.text_hint',
    label: 'کیک‌ساز — راهنمای فیلد متن روی کیک',
    defaultValue: 'مثلاً: تولدت مبارک سارا',
    group: 'کیک تولد سفارشی',
  ),
  AppTextEntry(
    key: 'cake.price_label',
    label: 'کیک‌ساز — برچسب قیمت',
    defaultValue: 'قیمت:',
    group: 'کیک تولد سفارشی',
    required: true,
  ),
  AppTextEntry(
    key: 'cake.lead_note',
    label: 'کیک‌ساز — جمله زمان آماده‌سازی',
    defaultValue: '⏳ آماده‌سازی حداقل ۳ روز',
    group: 'کیک تولد سفارشی',
  ),
  AppTextEntry(
    key: 'cake.add_button',
    label: 'کیک‌ساز — دکمه افزودن به سبد',
    defaultValue: 'افزودن به سبد 🛒',
    group: 'کیک تولد سفارشی',
    required: true,
  ),
  AppTextEntry(
    key: 'cake.added_snackbar',
    label: 'کیک‌ساز — پیام بعد از افزودن',
    defaultValue: 'به سبد اضافه شد 🎂',
    group: 'کیک تولد سفارشی',
  ),
  AppTextEntry(
    key: 'cake.summary_prefix',
    label: 'کیک‌ساز — شروع خلاصه سفارش',
    defaultValue: 'کیک',
    group: 'کیک تولد سفارشی',
    required: true,
  ),
  AppTextEntry(
    key: 'cake.summary_middle',
    label: 'کیک‌ساز — حرف «با» در خلاصه',
    defaultValue: 'با فیلینگ',
    group: 'کیک تولد سفارشی',
    required: true,
  ),
  AppTextEntry(
    key: 'cake.summary_text_label',
    label: 'کیک‌ساز — برچسب متن کیک در خلاصه',
    defaultValue: 'متن:',
    group: 'کیک تولد سفارشی',
    required: true,
  ),
];

/// نگاشت کلید → پیش‌فرض (برای fallback سریع).
final Map<String, String> appTextDefaults = {
  for (final e in appTextEntries) e.key: e.defaultValue,
};

/// گروه‌ها به ترتیب نمایش در پنل مدیر.
const List<String> appTextGroups = [
  'صفحه خانه',
  'کیک تولد سفارشی',
];

/// دسترسی به متن‌ها در ویجت‌ها: `context.texts.t('home.headline')`
class AppTexts extends InheritedNotifier<AppTextsNotifier> {
  const AppTexts({
    super.key,
    required AppTextsNotifier notifier,
    required super.child,
  }) : super(notifier: notifier);

  /// کلید را برمی‌گرداند؛ اگر نبود یا خالی بود، پیش‌فرضش.
  String t(String key) => notifier!.t(key);

  /// دسترسی مستقیم به نوتیفایر (برای به‌روزرسانی از پنل مدیر).
  AppTextsNotifier get texts => notifier!;

  /// نسخه‌ی ایمن برای جاهایی که شاید بالای درخت AppTexts نباشد.
  static AppTexts of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppTexts>() ??
      AppTexts(
        notifier: AppTextsNotifier(),
        child: const SizedBox.shrink(),
      );

  @override
  bool updateShouldNotify(AppTexts oldWidget) =>
      oldWidget.notifier != notifier;}

/// نگه‌دارنده متن‌ها + اعلان تغییر به ویجت‌ها.
///
/// مقدارهای `required` هیچ‌وقت خالی نمی‌شوند: اگر مدیر خالی بگذارد،
/// مقدار پیش‌فرض برمی‌گردد تا دکمه/عنوان گم نشود.
class AppTextsNotifier extends ChangeNotifier {
  final Map<String, String> _values = {};

  /// کپی مقادیر فعلی (برای ذخیره در سرور).
  Map<String, String> get values => Map.of(_values);

  void replaceAll(Map<String, String> incoming) {
    _values
      ..clear()
      ..addAll(_sanitize(incoming));
    notifyListeners();
  }

  /// مقدار متن برای [key]؛ خالی/ناموجود → پیش‌فرض.
  String t(String key) {
    final v = _values[key]?.trim() ?? '';
    if (v.isNotEmpty) return v;
    return appTextDefaults[key] ?? '';
  }

  /// ذخیره پیش‌فرض‌های خالی‌نشده را کامل می‌کند.
  void fillDefaults() => replaceAll({...appTextDefaults, ..._values});

  /// پاک‌سازی: فقط کلیدهای شناخته‌شده، بدون خالی.
  /// کلید ناشناس (تایپی یا از نسخه قدیمی) هرگز وارد state نمی‌شود؛
  /// متن خالی هم ذخیره نمی‌شود تا پیش‌فرضش برگردد.
  static Map<String, String> _sanitize(Map<String, String> input) =>
      cleanForStore(input);

  /// ذخیره‌ی پاک‌شده‌ی مقادیر (برای فرستادن به سرور/لوکال).
  static Map<String, String> cleanForStore(Map<String, String> input) {
    final out = <String, String>{};
    input.forEach((k, v) {
      final key = k.trim();
      final val = v.trim();
      if (key.isEmpty || val.isEmpty) return;
      if (!appTextDefaults.containsKey(key)) return;
      out[key] = val;
    });
    return out;
  }
}
