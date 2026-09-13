import 'package:shared_preferences/shared_preferences.dart';

/// سرویس احراز هویت ساده:
/// - حالت آفلاین/دمو: هش رمز در SharedPreferences (نه خود رمز)
/// - وقتی سوپابیس وصل شد: همین نام‌کاربری به username@qand.local مپ می‌شود
/// نقش مدیر: username == admin
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
      // مسیر اصلی: هش رمز دقیق (بدون trim — فاصله جزئی از رمز است)
      if (stored == hashPassword(username, password)) return true;
      // سازگاری با نسخه قدیم که password را trim می‌کرد:
      // اگر کاربر قدیمی با رمز دارای فاصله ثبت‌نام کرده بود، لاگین را خراب نکن
      final trimmed = password.trim();
      if (trimmed != password && stored == hashPassword(username, trimmed)) {
        return true;
      }
      return false;
    }
    // سازگاری با نسخه قدیم که رمز plaintext ذخیره می‌کرد (هم raw هم trim)
    return stored == password || stored == password.trim();
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
    // رمز عمدا trim نمی‌شود (ثبت‌نام هم همین‌طور) — _matches برای
    // سازگاری با حساب‌های قدیمی، حالت trimشده را هم امتحان می‌کند.
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
    if (saved == null || !_matches(username, password, saved)) return false;
    // ارتقا: اگر رکورد قدیمی plaintext بود، به هش تبدیلش کن.
    // از خود مقدار ذخیره‌شده (نسخه trimشده قدیمی) هش می‌سازیم تا
    // کاربر قدیمی با همان رمزی که قبلا وارد می‌کرد همچنان وارد شود،
    // و لاگین با فاصله اضافی هم از طریق fallback در _matches کار کند.
    if (!saved.startsWith('v1\$')) {
      await p.setString('user_$username', hashPassword(username, saved));
    }
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
