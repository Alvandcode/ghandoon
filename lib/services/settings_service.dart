import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import 'supabase_service.dart';

/// تنظیمات قابل ویرایش توسط مدیر از داخل اپ:
/// شماره کارت + صاحب حساب + لینک زرین‌پال
///
/// استراتژی دو‌لایه (بدون کرش در هر حالت):
/// 1. اگر سوپابیس وصل است: خواندن/نوشتن از جدول `app_settings` (ردیف id=1).
/// 2. همیشه آینه لوکال در SharedPreferences تا آفلاین هم کار کند.
/// 3. در هر خطای شبکه، نسخه لوکال برگردانده می‌شود.
class SettingsService {
  static const _kCard = 'set_card';
  static const _kOwner = 'set_owner';
  static const _kZarin = 'set_zarin';

  Future<Map<String, String>> load() async {
    final local = await _loadLocal();
    final client = SupabaseService.clientOrNull();
    if (client == null) return local;
    try {
      final row = await client
          .from('app_settings')
          .select('card_number, card_owner, zarinpal_link')
          .eq('id', 1)
          .maybeSingle();
      if (row == null) return local;
      final m = Map<String, dynamic>.from(row);
      final card = '${m['card_number'] ?? ''}'.trim();
      final owner = '${m['card_owner'] ?? ''}'.trim();
      final zarin = '${m['zarinpal_link'] ?? ''}'.trim();
      // آینه لوکال تا دفعه بعد آفلاین هم تازه باشد
      final p = await SharedPreferences.getInstance();
      if (card.isNotEmpty) await p.setString(_kCard, card);
      if (owner.isNotEmpty) await p.setString(_kOwner, owner);
      // زرین‌پال خالی معتبر است (یعنی غیرفعال) — همیشه آینه کن
      await p.setString(_kZarin, zarin);
      return {
        'card': card.isEmpty ? local['card']! : card,
        'owner': owner.isEmpty ? local['owner']! : owner,
        'zarin': zarin,
      };
    } catch (_) {
      return local;
    }
  }

  Future<Map<String, String>> _loadLocal() async {
    final p = await SharedPreferences.getInstance();
    return {
      'card': p.getString(_kCard) ?? AppConfig.defaultCardNumber,
      'owner': p.getString(_kOwner) ?? AppConfig.defaultCardOwner,
      'zarin': p.getString(_kZarin) ?? AppConfig.defaultZarinpalLink,
    };
  }

  Future<void> save({required String card, required String owner, required String zarin}) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kCard, card);
    await p.setString(_kOwner, owner);
    await p.setString(_kZarin, zarin);
    // تلاش برای همگام‌سازی با سرور؛ شکست = فقط لوکال (آفلاین) بدون خطا به کاربر
    final client = SupabaseService.clientOrNull();
    if (client == null) return;
    try {
      await client.from('app_settings').upsert({
        'id': 1,
        'card_number': card,
        'card_owner': owner,
        'zarinpal_link': zarin,
      });
    } catch (_) {
      // نادیده: لوکال ذخیره شده و اپ ادامه می‌دهد
    }
  }
}
