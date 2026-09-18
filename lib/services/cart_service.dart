import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/cart_item.dart';

/// سبد خرید چندمحصولی (لوکال، جدا برای هر کاربر).
/// کلید: `qand_cart_<username>`. رکورد خراب نادیده گرفته می‌شود.
class CartService {
  String _key(String username) => 'qand_cart_${username.trim()}';

  Future<List<CartItem>> items(String username) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList(_key(username)) ?? [];
    final list = <CartItem>[];
    for (final s in raw) {
      try {
        final m = jsonDecode(s) as Map<String, dynamic>;
        final item = CartItem.fromJson(m);
        if (item.uid.isEmpty || item.title.isEmpty) continue;
        list.add(item);
      } catch (_) {
        // رکورد خراب را نادیده بگیر
      }
    }
    return list;
  }

  Future<int> count(String username) async => (await items(username)).length;

  Future<int> total(String username) async {
    final list = await items(username);
    var sum = 0;
    for (final i in list) {
      sum += i.total;
    }
    return sum;
  }

  /// افزودن قلم جدید (uid یکتا می‌سازد) و قلم را برمی‌گرداند.
  Future<CartItem> add({
    required String username,
    required String productId,
    required String title,
    required int unitPrice,
    int qty = 1,
    String unit = 'عدد',
    String options = '',
    int leadDays = 1,
  }) async {
    final item = CartItem(
      uid: '${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(1 << 32)}',
      productId: productId,
      title: title,
      unitPrice: unitPrice < 0 ? 0 : unitPrice,
      qty: qty.clamp(1, 99),
      unit: unit,
      options: options,
      leadDays: leadDays.clamp(1, 30),
    );
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList(_key(username)) ?? [];
    raw.add(jsonEncode(item.toJson()));
    await p.setStringList(_key(username), raw);
    return item;
  }

  /// تغییر تعداد یک قلم. qty<=0 یعنی حذف. false یعنی قلم پیدا نشد.
  Future<bool> setQty(String username, String uid, int qty) async {
    final p = await SharedPreferences.getInstance();
    final key = _key(username);
    final raw = p.getStringList(key) ?? [];
    var found = false;
    final out = <String>[];
    for (final s in raw) {
      try {
        final item = CartItem.fromJson(jsonDecode(s) as Map<String, dynamic>);
        if (item.uid == uid) {
          found = true;
          if (qty <= 0) continue; // حذف
          out.add(jsonEncode(item.copyWith(qty: qty.clamp(1, 99)).toJson()));
        } else {
          out.add(s);
        }
      } catch (_) {
        // رکورد خراب را دور بریز تا سبد تمیز بماند
      }
    }
    if (found) await p.setStringList(key, out);
    return found;
  }

  Future<bool> remove(String username, String uid) =>
      setQty(username, uid, 0);

  Future<void> clear(String username) async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_key(username));
  }
}
