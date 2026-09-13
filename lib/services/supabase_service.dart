import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';

/// راه‌اندازی اختیاری سوپابیس:
/// - اگر SUPABASE_URL و SUPABASE_ANON_KEY با --dart-define داده شده باشند وصل می‌شود.
/// - وگرنه اپ در حالت دموی آفلاین (حافظه لوکال) کار می‌کند و هیچ کرشی رخ نمی‌دهد.
///
/// همه سرویس‌ها باید اول [clientOrNull] را چک کنند و در صورت null به
/// fallback لوکال برگردند. هیچ‌کدام نباید مستقیم Supabase.instance را صدا بزنند
/// چون در حالت آفلاین اکسپشن می‌دهد.
class SupabaseService {
  static bool _ready = false;

  static bool get isReady => _ready;

  static Future<void> initIfConfigured() async {
    if (!AppConfig.hasSupabase) return;
    try {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        anonKey: AppConfig.supabaseAnonKey,
      );
      _ready = true;
    } catch (_) {
      // اتصال ناموفق = ادامه در حالت آفلاین
      _ready = false;
    }
  }

  /// کلاینت آماده یا null در حالت آفلاین. هرگز throw نمی‌کند.
  static SupabaseClient? clientOrNull() {
    if (!_ready) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }
}
