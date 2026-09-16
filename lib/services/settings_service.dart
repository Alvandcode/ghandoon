import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import 'supabase_service.dart';

/// تنظیمات عمومی (شماره کارت + صاحب حساب + لینک زرین‌پال)
///
/// ⚠️ این سرویس فقط-خواندنی است:
/// تغییر شماره کارت/زرین‌پال فقط از داشبورد سوپابیس (با service_role) انجام شود.
/// قبلاً upsert از کلاینت انجام می‌شد که با anon key داخل APK یعنی هر کسی
/// می‌توانست شماره کارت را عوض کند (ریسک تقلب مالی) — این مسیر حذف شد.
///
/// استراتژی خواندن (بدون کرش در هر حالت):
/// 1. اگر سوپابیس وصل است: خواندن از جدول `app_settings` (ردیف id=1).
/// 2. همیشه آینه لوکال در SharedPreferences تا آفلاین هم کار کند.
/// 3. در هر خطای شبکه، نسخه لوکال برگردانده می‌شود.
///
/// متد [save] فقط آینه لوکال را به‌روز می‌کند (فقط برای حالت دموی آفلاین/توسعه
/// بدون سوپابیس به کار می‌رود) و هرگز به سرور چیزی نمی‌نویسد.
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

  /// فقط آینه لوکال (حالت دمو/آفلاین). وقتی سوپابیس وصل است نوشتن از کلاینت
  /// ممکن نیست (RLS) و نباید هم باشد؛ سرچشمه‌ی حقیقت داشبورد سوپابیس است.
  Future<void> saveLocalMirror({
    required String card,
    required String owner,
    required String zarin,
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kCard, card);
    await p.setString(_kOwner, owner);
    await p.setString(_kZarin, zarin);
  }
}
