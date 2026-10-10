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
  static const _kBranchImages = 'set_branch_images';

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
      // عکس شاخه‌ها را جدا می‌خوانیم تا اگر ستونش روی سرور قدیمی نباشد،
      // کل بارگذاری تنظیمات به لوکال نیفتد.
      final imgs = await _remoteBranchImages(client);
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
      if (imgs != null) {
        await p.setString(_kBranchImages, jsonEncode(imgs));
      }
      final localImgs =
          decodeBranchImages(local['branchImages'] ?? '');
      return {
        'card': card.isEmpty ? local['card']! : card,
        'owner': owner.isEmpty ? local['owner']! : owner,
        'zarin': zarin,
        'mainCategories': jsonEncode(cats),
        'branchImages': jsonEncode(imgs ?? localImgs),
      };
    } catch (_) {
      return local;
    }
  }

  Future<Map<String, String>> _loadLocal() async {
    final p = await SharedPreferences.getInstance();
    final cats = sanitizeMainCategories(
        decodeMainCategories(p.getString(_kMainCategories) ?? ''));
    final imgs = sanitizeBranchImages(
        decodeBranchImages(p.getString(_kBranchImages) ?? ''));
    return {
      'card': p.getString(_kCard) ?? AppConfig.defaultCardNumber,
      'owner': p.getString(_kOwner) ?? AppConfig.defaultCardOwner,
      'zarin': p.getString(_kZarin) ?? AppConfig.defaultZarinpalLink,
      'mainCategories': jsonEncode(cats),
      'branchImages': jsonEncode(imgs),
    };
  }

  /// سقف تعداد شاخه‌ها (صفحه خانه ۲ ستونه است؛ بیشتر از این شلوغ می‌شود).
  static const int maxMainCategories = 8;

  /// شاخه‌های اصلی سفارش (داینامیک: ۱ تا [maxMainCategories] مورد معتبر).
  /// هیچ‌وقت خالی برنمی‌گردد؛ ورودی کاملاً خالی → پیش‌فرض.
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

  /// خالی‌ها و تکراری‌ها حذف، سقف [maxMainCategories]؛
  /// ورودی کاملاً خالی → لیست پیش‌فرض (فروشگاه هیچ‌وقت بی‌شاخه نمی‌ماند).
  static List<String> sanitizeMainCategories(List<String> input) {
    final out = <String>[];
    for (final raw in input) {
      final t = raw.trim();
      if (t.isEmpty) continue;
      if (out.contains(t)) continue;
      out.add(t);
      if (out.length == maxMainCategories) break;
    }
    if (out.isEmpty) return List.of(AppConfig.defaultMainCategories);
    return out;
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

  // ---------------- عکس شاخه‌ها (آیکون گالری) ----------------
  // نگاشت نام شاخه → URL عکس. کلید نام است (نه ایندکس) تا حذف یک شاخه،
  // عکس بقیه را جابه‌جا نکند. حذف شاخه = حذف ورودی عکسش.

  /// decode امن نگاشت عکس‌ها؛ ورودی خراب → نقشه خالی.
  static Map<String, String> decodeBranchImages(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return const {};
    try {
      final v = jsonDecode(s);
      if (v is Map) {
        final out = <String, String>{};
        v.forEach((k, val) {
          final key = '$k'.trim();
          final url = '$val'.trim();
          if (key.isNotEmpty && url.isNotEmpty) out[key] = url;
        });
        return out;
      }
    } catch (_) {}
    return const {};
  }

  /// ورودی‌های خالی/تکراریِ بی‌فایده را تمیز می‌کند (بدون تحمیل پیش‌فرض).
  static Map<String, String> sanitizeBranchImages(Map<String, String> input) {
    final out = <String, String>{};
    input.forEach((k, v) {
      final key = k.trim();
      final url = v.trim();
      if (key.isEmpty || url.isEmpty) return;
      out[key] = url;
    });
    return out;
  }

  /// عکس‌های ذخیره‌شده همه شاخه‌ها (نام → URL).
  Future<Map<String, String>> loadBranchImages() async {
    final m = await load();
    return sanitizeBranchImages(
        decodeBranchImages(m['branchImages'] ?? ''));
  }

  /// خواندن best-effort عکس‌ها از سرور؛ null یعنی ستون نیست/آفلاین/خطا.
  Future<Map<String, String>?> _remoteBranchImages(dynamic client) async {
    try {
      final row = await client
          .from('app_settings')
          .select('branch_images')
          .eq('id', 1)
          .maybeSingle();
      if (row == null) return null;
      final m = Map<String, dynamic>.from(row as Map);
      return sanitizeBranchImages(
          decodeBranchImages('${m['branch_images'] ?? ''}'));
    } catch (_) {
      return null;
    }
  }

  /// نوشتن واقعی عکس‌ها: اول سرور، بعد آینه لوکال.
  /// ورودی شاخه‌های حذف‌شده را نگه نمی‌دارد اگر [validTitles] داده شود.
  Future<bool> saveBranchImages(Map<String, String> images,
      {List<String>? validTitles}) async {
    var imgs = sanitizeBranchImages(images);
    if (validTitles != null) {
      final keep = validTitles.map((e) => e.trim()).toSet();
      imgs = {for (final e in imgs.entries) if (keep.contains(e.key)) e.key: e.value};
    }
    final encoded = jsonEncode(imgs);
    var remoteOk = false;
    final client = SupabaseService.clientOrNull();
    if (client != null) {
      try {
        await client.from('app_settings').update({
          'branch_images': encoded,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', 1);
        remoteOk = true;
      } catch (_) {
        remoteOk = false;
      }
    }
    final p = await SharedPreferences.getInstance();
    await p.setString(_kBranchImages, encoded);
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
