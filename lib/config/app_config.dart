// تنظیمات سراسری اپ. شماره کارت و لینک زرین‌پال از پنل مدیر قابل ویرایش است.
// مقادیر پیش‌فرض اینجاست تا قبل از اتصال سوپابیس هم اپ کار کند.

class AppConfig {
  // اگر سوپابیس وصل نباشد از این‌ها استفاده می‌شود
  static const String defaultCardNumber = '6037-9911-1234-5678';
  static const String defaultCardOwner = 'فروشگاه قندون';
  // لینک زرین‌پال را بعدا اینجا یا از پنل مدیر عوض کن. خالی = دکمه مخفی
  static const String defaultZarinpalLink = '';

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static const String supportPhone = '09130000000';
  static const String whatsappNumber = '989130000000';
}
