import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import 'supabase_service.dart';

/// تنظیمات عمومی (شماره کارت + صاحب حساب + لینک زرین‌پال + دسته‌های اصلی)
///
/// استراتژی خواندن (بدون کرش در هر حالت):
/// 1. اگر سوپابیس وصل است: خواندن از جدول `app_settings` (ردیف id=1).
/// 2. همیشه آینه لوکال در SharedPreferences تا آفلاین هم کار کند.
/// 3. در هر خطای شبکه، نسخه لوکال برگردانده می‌شود.
///
/// نوشتن با [save]: اول سرور (تا همه کاربران ببینند)، بعد آینه لوکال.
/// پیش‌نیاز: پالیسی "app_settings demo write" روی سرور.
/// ⚠️ تا قبل از مهاجرت به Supabase Auth، هر کسی با کلید داخل APK از نظر
/// فنی می‌تواند این‌ها را عوض کند — شماره کارت را دوره‌ای چک کن.
class SettingsService {
  static const _kCard = 'set_card';
  static const _kOwner = 'set_owner';
  static const _kZarin = 'set_zarin';
  static const _kMainCategories = 'set_main_categories';

  Future<Map<String, String>> load() async {
    final local = await _loadLocal();
    final client = SupabaseService.clientOrNull();
    if (client == null) return local;
    try {
      final row = await client
          .from('app_settings')
          .select('card_number, card_owner, zarinpal_link, main_categories')
          .eq('id', 1)
          .maybeSingle();
      if (row == null) return local;
      final m = Map<String, dynamic>.from(row);
      final card = '${m['card_number'] ?? ''}'.trim();
      final owner = '${m['card_owner'] ?? ''}'.trim();
      final zarin = '${m['zarinpal_link'] ?? ''}'.trim();
      final catsRaw = '${m['main_categories'] ?? ''}';
      // آینه لوکال تا دفعه بعد آفلاین هم تازه باشد
      final p = await SharedPreferences.getInstance();
      if (card.isNotEmpty) await p.setString(_kCard, card);
      if (owner.isNotEmpty) await p.setString(_kOwner, owner);
      // زرین‌پال خالی معتبر است (یعنی غیرفعال) — همیشه آینه کن
      await p.setString(_kZarin, zarin);
      final cats = sanitizeMainCategories(decodeMainCategories(catsRaw));
      if (catsRaw.isNotEmpty) {
        await p.setString(_kMainCategories, jsonEncode(cats));
      }
      return {
        'card': card.isEmpty ? local['card']! : card,
        'owner': owner.isEmpty ? local['owner']! : owner,
        'zarin': zarin,
        'mainCategories': jsonEncode(cats),
      };
    } catch (_) {
      return local;
    }
  }

  Future<Map<String, String>> _loadLocal() async {
    final p = await SharedPreferences.getInstance();
    final cats = sanitizeMainCategories(
        decodeMainCategories(p.getString(_kMainCategories) ?? ''));
    return {
      'card': p.getString(_kCard) ?? AppConfig.defaultCardNumber,
      'owner': p.getString(_kOwner) ?? AppConfig.defaultCardOwner,
      'zarin': p.getString(_kZarin) ?? AppConfig.defaultZarinpalLink,
      'mainCategories': jsonEncode(cats),
    };
  }

  /// چهار شاخه اصلی سفارش (همیشه دقیقاً ۴ مورد معتبر).
  Future<List<String>> loadMainCategories() async {
    final m = await load();
    return sanitizeMainCategories(decodeMainCategories(m['mainCategories'] ?? ''));
  }

  /// decode امن JSON لیست دسته‌ها؛ ورودی خراب → لیست خالی.
  static List<String> decodeMainCategories(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return const [];
    try {
      final v = jsonDecode(s);
      if (v is List) return [for (final e in v) '$e'];
    } catch (_) {}
    return const [];
  }

  /// دقیقاً ۴ دسته: خالی‌ها حذف، تکراری‌ها حذف، کمبود با پیش‌فرض پر می‌شود.
  static List<String> sanitizeMainCategories(List<String> input) {
    final out = <String>[];
    for (final raw in input) {
      final t = raw.trim();
      if (t.isEmpty) continue;
      if (out.contains(t)) continue;
      out.add(t);
      if (out.length == 4) break;
    }
    for (final d in AppConfig.defaultMainCategories) {
      if (out.length == 4) break;
      if (!out.contains(d)) out.add(d);
    }
    return out.take(4).toList();
  }

  /// نوشتن واقعی دسته‌ها: اول سرور، بعد آینه لوکال.
  Future<bool> saveMainCategories(List<String> categories) async {
    final cats = sanitizeMainCategories(categories);
    final encoded = jsonEncode(cats);
    var remoteOk = false;
    final client = SupabaseService.clientOrNull();
    if (client != null) {
      try {
        await client.from('app_settings').update({
          'main_categories': encoded,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', 1);
        remoteOk = true;
      } catch (_) {
        remoteOk = false;
      }
    }
    final p = await SharedPreferences.getInstance();
    await p.setString(_kMainCategories, encoded);
    return remoteOk;
  }

  /// ذخیره واقعی: اول سرور (تا همه کاربران ببینند)، بعد آینه لوکال.
  /// true = روی سرور ذخیره شد؛ false = فقط لوکال (آفلاین یا دسترسی بسته).
  /// پیش‌نیاز سمت سرور: پالیسی "app_settings demo write" (بخش دسترسی‌های اپ در README).
  Future<bool> save({
    required String card,
    required String owner,
    required String zarin,
  }) async {
    var remoteOk = false;
    final client = SupabaseService.clientOrNull();
    if (client != null) {
      try {
        await client.from('app_settings').update({
          'card_number': card,
          'card_owner': owner,
          'zarinpal_link': zarin,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', 1);
        remoteOk = true;
      } catch (_) {
        remoteOk = false;
      }
    }
    await saveLocalMirror(card: card, owner: owner, zarin: zarin);
    return remoteOk;
  }

  /// فقط آینه لوکال (برای fallback آفلاین؛ [save] خودش صدایش می‌زند).
  /// مستقیم صدا نزن مگر در حالت دموی بدون سرور.
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
