import 'package:shared_preferences/shared_preferences.dart';

/// سرویس احراز هویت ساده (حالت آفلاین/دمو):
/// - هش رمز در SharedPreferences (نه خود رمز)
/// - وقتی سوپابیس وصل شد: همین نام‌کاربری به username@qand.local مپ می‌شود
/// نقش مدیر: username == admin
///
/// ⚠️ محدودیت‌های امنیتی این حالت دمو:
/// - هش DJB2 قطعی و سبک است (نه bcrypt/argon2) — برای دمو کافی است، برای محصول
///   واقعی باید به Supabase Auth مهاجرت شود.
/// - مسیرهای سازگاری نسخه‌های قدیمی (مقایسه plaintext و هشِ رمز trim شده) حذف شد:
///   رکوردهای قدیمی دیگر قابل لاگین نیستند؛ در اولین ورود با رمزِ دقیقِ قدیمی
///   مقدار plaintext به هش ارتقا می‌یافت که این مسیر هم اکنون بسته است.
class AuthService {
  static const _kUser = 'qand_user';
  static const _kRole = 'qand_role';
  static const _defaultAdminUser = 'admin';
  static const _defaultAdminPass = '1234';

  /// هش قطعی و سبک (DJB2 دو مرحله‌ای با نمک، ماسک 31 بیتی) — بدون نیاز به پکیج اضافه.
  /// همه ثابت‌ها کوچک‌اند تا در محدوده int64 د Dart جا شوند.
  /// برای دموی آفلاین کافی است تا رمز به‌صورت متن ساده ذخیره نشود.
  /// نکته: برای محصول واقعی باید به Supabase Auth مهاجرت شود.
  static String hashPassword(String username, String password) {
    final salted = 'qand|$username|$password|qand';
    final h1 = _djb2(salted);
    final h2 = _djb2('$salted#$h1');
    return 'v1\$$h1\$$h2';
  }

  static int _djb2(String s) {
    var h = 5381;
    for (var i = 0; i < s.length; i++) {
      h = (((h << 5) + h) + s.codeUnitAt(i)) & 0x7FFFFFFF;
    }
    return h;
  }

  static bool _matches(String username, String password, String stored) {
    if (stored.startsWith('v1\$')) {
      // فقط مقایسه دقیق — رمز trim نمی‌شود (فاصله جزئی از رمز است)
      return stored == hashPassword(username, password);
    }
    // رکورد قدیمی plaintext: فقط برای ارتقا استفاده می‌شود، لاگین نمی‌شود.
    return false;
  }

  Future<bool> register(String username, String password) async {
    username = username.trim();
    // نکته امنیتی: رمز trim نمی‌شود تا فاصله ابتدایی/انتهایی بخشی از رمز باشد.
    // فقط نام‌کاربری نرمال می‌شود.
    if (username.length < 3 || password.length < 4) return false;
    // نام admin (با هر بزرگی/کوچکی حروف) رزرو است: فقط از مسیر لاگین پیش‌فرض
    // ساخته می‌شود تا کسی نتواند با ثبت‌نام زودهنگام، حساب مدیر را تصاحب کند.
    if (username.toLowerCase() == _defaultAdminUser) return false;
    final p = await SharedPreferences.getInstance();
    final key = 'user_$username';
    if (p.containsKey(key)) return false;
    await p.setString(key, hashPassword(username, password));
    await p.setString(_kUser, username);
    await p.setString(_kRole, username == _defaultAdminUser ? 'admin' : 'user');
    return true;
  }

  Future<bool> login(String username, String password) async {
    username = username.trim();
    // رمز عمدا trim نمی‌شود (ثبت‌نام هم همین‌طور).
    if (username.isEmpty || password.isEmpty) return false;
    final p = await SharedPreferences.getInstance();
    // ادمین پیش‌فرض: admin / 1234 (اولین ورود؛ بعدا از پنل عوض کن)
    if (username == _defaultAdminUser &&
        password == _defaultAdminPass &&
        !p.containsKey('user_$_defaultAdminUser')) {
      await p.setString('user_$_defaultAdminUser',
          hashPassword(_defaultAdminUser, _defaultAdminPass));
    }
    final saved = p.getString('user_$username');
    if (saved == null) return false;
    // ارتقای یک‌طرفه رکورد plaintext قدیمی به هش: فقط وقتی رمزِ واردشده دقیقاً
    // برابر مقدار ذخیره‌شده‌ی قدیمی باشد. سپس همان بار لاگین هم انجام می‌شود.
    if (!saved.startsWith('v1\$')) {
      if (password != saved) return false;
      await p.setString('user_$username', hashPassword(username, password));
      await p.setString(_kUser, username);
      await p.setString(_kRole, username == _defaultAdminUser ? 'admin' : 'user');
      return true;
    }
    if (!_matches(username, password, saved)) return false;
    // نقش فقط از روی رکورد معتبر: فقط کاربر دقیقا 'admin' مدیر است.
    // (ثبت‌نام 'Admin'/'ADMIN' از قبل بلاک است؛ این شرط جعل نقش را می‌بندد)
    await p.setString(_kUser, username);
    await p.setString(_kRole, username == _defaultAdminUser ? 'admin' : 'user');
    return true;
  }

  Future<void> logout() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kUser);
    await p.remove(_kRole);
  }

  Future<String?> currentUser() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kUser);
  }

  Future<bool> isAdmin() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kRole) == 'admin';
  }
}
