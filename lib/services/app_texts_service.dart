import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_texts.dart';
import 'supabase_service.dart';

/// سرویس متن‌های قابل‌ویرایش:
/// - خواندن: جدول/ستون `app_settings.app_texts` (JSON object) + آینه لوکال.
/// - نوشتن: اول سرور، بعد آینه لوکال.
/// - اگر ستون روی سرور قدیمی نباشد یا آفلاین باشیم، فقط لوکال استفاده می‌شود
///   و صفحه‌ها هیچ‌وقت متن خالی نشان نمی‌دهند (پیش‌فرض‌ها در AppTexts هستند).
class AppTextsService {
  static const _kTexts = 'app_texts_v1';

  /// خواندن همه متن‌ها (کلید → متن). ورودی خراب → نقشه خالی.
  Future<Map<String, String>> load() async {
    final local = await _loadLocal();
    final client = SupabaseService.clientOrNull();
    if (client == null) return local;
    try {
      final row = await client
          .from('app_settings')
          .select('app_texts')
          .eq('id', 1)
          .maybeSingle();
      if (row == null) return local;
      final m = Map<String, dynamic>.from(row as Map);
      final remote = decodeTexts('${m['app_texts'] ?? ''}');
      // آینه لوکال تا آفلاین هم تازه باشد (فقط وقتی سرور چیزی دارد)
      if (remote.isNotEmpty) {
        await _saveLocal(remote);
        return remote;
      }
      return local;
    } catch (_) {
      return local;
    }
  }

  /// نوشتن: اول سرور، بعد آینه لوکال. true = روی سرور ذخیره شد.
  Future<bool> save(Map<String, String> texts) async {
    final clean = AppTextsNotifier.cleanForStore(texts);
    final encoded = jsonEncode(clean);
    var remoteOk = false;
    final client = SupabaseService.clientOrNull();
    if (client != null) {
      try {
        await client.from('app_settings').update({
          'app_texts': encoded,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', 1);
        remoteOk = true;
      } catch (_) {
        remoteOk = false;
      }
    }
    await _saveLocal(clean);
    return remoteOk;
  }

  /// decode امن JSON object متن‌ها؛ خراب/خالی → نقشه خالی.
  static Map<String, String> decodeTexts(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return {};
    try {
      final v = jsonDecode(s);
      if (v is Map) {
        final out = <String, String>{};
        v.forEach((k, val) {
          final key = '$k'.trim();
          final text = '$val'.trim();
          // فقط کلیدهای شناخته‌شده و متن‌های پر
          if (key.isNotEmpty && text.isNotEmpty && appTextDefaults.containsKey(key)) {
            out[key] = text;
          }
        });
        return out;
      }
    } catch (_) {}
    return {};
  }

  Future<Map<String, String>> _loadLocal() async {
    try {
      final p = await SharedPreferences.getInstance();
      return decodeTexts(p.getString(_kTexts) ?? '');
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveLocal(Map<String, String> texts) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_kTexts, jsonEncode(texts));
    } catch (_) {}
  }
}
