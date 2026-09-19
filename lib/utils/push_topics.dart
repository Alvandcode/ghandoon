// کمک‌های خالص پوش (بدون وابستگی به فایربیس — تست‌پذیر).
// تاپیک FCM فقط [a-zA-Z0-9-_.~%] را قبول می‌کند، پس نام‌کاربری فارسی
// باید percent-encode شود. همین منطق در Edge Function سمت سرور هم هست
// (supabase/functions/_shared/topic.ts) — اگر عوضش کردی آن را هم عوض کن.

/// تاپیک اعلان همه مدیران.
const adminPushTopic = 'orders_admin';

/// تاپیک شخصی یک کاربر. خالی/فاصله → 'user_guest'.
String pushTopicForUser(String username) {
  final name = username.trim().toLowerCase();
  if (name.isEmpty) return 'user_guest';
  final bytes = _utf8(name);
  final buf = StringBuffer('user_');
  for (final b in bytes) {
    if ((b >= 0x30 && b <= 0x39) || // 0-9
        (b >= 0x61 && b <= 0x7A) || // a-z
        b == 0x2D || // -
        b == 0x2E || // .
        b == 0x5F || // _
        b == 0x7E) {
      // ~
      buf.writeCharCode(b);
    } else {
      buf.write('%');
      buf.write(_hex(b));
    }
  }
  final t = buf.toString();
  // سقف FCM حدود ۹۰۰ کاراکتر است؛ نام‌کاربری کوتاه است ولی محض اطمینان.
  return t.length <= 900 ? t : t.substring(0, 900);
}

List<int> _utf8(String s) {
  final out = <int>[];
  for (final rune in s.runes) {
    final c = rune;
    if (c < 0x80) {
      out.add(c);
    } else if (c < 0x800) {
      out.add(0xC0 | (c >> 6));
      out.add(0x80 | (c & 0x3F));
    } else if (c < 0x10000) {
      out.add(0xE0 | (c >> 12));
      out.add(0x80 | ((c >> 6) & 0x3F));
      out.add(0x80 | (c & 0x3F));
    } else {
      out.add(0xF0 | (c >> 18));
      out.add(0x80 | ((c >> 12) & 0x3F));
      out.add(0x80 | ((c >> 6) & 0x3F));
      out.add(0x80 | (c & 0x3F));
    }
  }
  return out;
}

String _hex(int b) =>
    b.toRadixString(16).toUpperCase().padLeft(2, '0');

/// استخراج نمایشی از پیام FCM برای نمایش دستی در فورگراند.
/// data کلیدهای orderId/order_id و status را دارد (ساخته Edge Function).
class PushDisplay {
  final String title;
  final String body;
  final String orderId;
  const PushDisplay(
      {required this.title, required this.body, required this.orderId});
}

PushDisplay pushDisplayFromData(
  Map<String, String> data, {
  String? notificationTitle,
  String? notificationBody,
}) {
  final orderId = data['orderId'] ?? data['order_id'] ?? '';
  final title = (notificationTitle ?? '').trim().isNotEmpty
      ? notificationTitle!.trim()
      : 'قندون 🧁';
  final body = (notificationBody ?? '').trim().isNotEmpty
      ? notificationBody!.trim()
      : 'سفارش $orderId به‌روز شد';
  return PushDisplay(title: title, body: body, orderId: orderId);
}
