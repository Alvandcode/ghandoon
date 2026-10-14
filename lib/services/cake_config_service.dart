import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/cake_config.dart';
import 'supabase_service.dart';

/// سرویس پیکربندی «کیک تولد سفارشی»:
/// - خواندن: `app_settings.cake_config` (JSON) + آینه لوکال.
/// - نوشتن: اول سرور، بعد آینه لوکال.
/// - اگر سرور نداشت/آفلاین بود → پیش‌فرض‌های [defaultCakeConfig] برمی‌گردند
///   تا صفحه هیچ‌وقت خالی نباشد.
class CakeConfigService {
  static const _kCake = 'cake_config_v1';

  Future<CakeConfig> load() async {
    final local = await _loadLocal();
    final client = SupabaseService.clientOrNull();
    if (client == null) return local;
    try {
      final row = await client
          .from('app_settings')
          .select('cake_config')
          .eq('id', 1)
          .maybeSingle();
      if (row == null) return local;
      final m = Map<String, dynamic>.from(row as Map);
      final remote = decodeConfig('${m['cake_config'] ?? ''}');
      if (remote != null) {
        await _saveLocal(remote);
        return remote;
      }
      return local;
    } catch (_) {
      return local;
    }
  }

  /// ذخیره (اول سرور، بعد لوکال). true = روی سرور نشست.
  Future<bool> save(CakeConfig config) async {
    final encoded = jsonEncode(config.toJson());
    var remoteOk = false;
    final client = SupabaseService.clientOrNull();
    if (client != null) {
      try {
        await client.from('app_settings').update({
          'cake_config': encoded,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', 1);
        remoteOk = true;
      } catch (_) {
        remoteOk = false;
      }
    }
    await _saveLocal(config);
    return remoteOk;
  }

  /// decode امن؛ خالی/خراب → null (یعنی «برگرد به پیش‌فرض»).
  static CakeConfig? decodeConfig(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;
    try {
      final v = jsonDecode(s);
      if (v is Map) {
        return CakeConfig.fromJson(Map<String, dynamic>.from(v));
      }
    } catch (_) {}
    return null;
  }

  Future<CakeConfig> _loadLocal() async {
    try {
      final p = await SharedPreferences.getInstance();
      return decodeConfig(p.getString(_kCake) ?? '') ?? defaultCakeConfig;
    } catch (_) {
      return defaultCakeConfig;
    }
  }

  Future<void> _saveLocal(CakeConfig config) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_kCake, jsonEncode(config.toJson()));
    } catch (_) {}
  }

  /// ساخت id یکتا برای بخش/گزینه جدید (تا دو تا هم‌نام قاطی نشوند).
  static String uniqueId(Set<String> taken, String prefix) {
    var i = 1;
    var candidate = '${prefix}_$i';
    while (taken.contains(candidate)) {
      i++;
      candidate = '${prefix}_$i';
    }
    return candidate;
  }
}