import 'package:flutter/material.dart';
import '../theme/qand_theme.dart';
import '../services/auth_service.dart';
import '../widgets/checker_strip.dart';
import '../widgets/safe_scaffold.dart';
import '../utils/responsive.dart';
import 'home_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _isLogin = true;
  bool _busy = false;
  String? _err;

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    // نام‌کاربری نرمال می‌شود؛ رمز عمدا trim نمی‌شود (فاصله جزئی از رمز است)
    final u = _user.text.trim();
    final p = _pass.text;
    if (u.length < 3 || p.length < 4) {
      setState(() => _err = 'نام کاربری حداقل ۳ و رمز حداقل ۴ کاراکتر');
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      final s = AuthService();
      final ok = _isLogin ? await s.login(u, p) : await s.register(u, p);
      if (!mounted) return;
      if (!ok) {
        setState(() => _err = _isLogin
            ? 'ورود ناموفق بود؛ نام کاربری یا رمز را بررسی کن'
            : (u.toLowerCase() == 'admin'
                ? 'این نام کاربری رزرو شده است'
                : 'این نام کاربری قبلا ثبت شده'));
        return;
      }
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomeScreen(username: u)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPad = topSafeOnly(context, extra: 12);
    return Scaffold(
      body: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: bottomSafeOnly(context, extra: 24)),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.only(top: topPad),
              constraints: BoxConstraints(minHeight: 220, maxHeight: 220 + topPad),
              decoration: QandTheme.headerGradient(),
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  // آدمک صفحه ورود — اندازه با عرض صفحه، دایره‌ای.
                  Builder(builder: (context) {
                    final s = Responsive.badge(
                        MediaQuery.sizeOf(context).width,
                        min: 100,
                        max: 140,
                        ratio: 0.32);
                    return ClipOval(
                      child: Image.asset('assets/images/auth_chef.png',
                          height: s,
                          width: s,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Text('👩‍🍳',
                              style: TextStyle(fontSize: 64))),
                    );
                  }),
                  const SizedBox(height: 8),
                  const Text('به قندون خوش اومدی', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                ]),
              ),
            ),
            const CheckerStrip(height: 16),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(children: [
                    Text(_isLogin ? 'ورود' : 'ثبت‌نام', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    TextField(controller: _user, decoration: const InputDecoration(labelText: 'نام کاربری', prefixIcon: Icon(Icons.person))),
                    const SizedBox(height: 12),
                    TextField(controller: _pass, obscureText: true, decoration: const InputDecoration(labelText: 'رمز شخصی', prefixIcon: Icon(Icons.lock))),
                    if (_err != null) ...[
                      const SizedBox(height: 8),
                      Text(_err!, style: const TextStyle(color: Colors.red)),
                    ],
                    const SizedBox(height: 16),
                    ElevatedButton(onPressed: _busy ? null : _submit, child: _busy
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(_isLogin ? 'ورود' : 'ساخت حساب')),
                    TextButton(
                      onPressed: () => setState(() => _isLogin = !_isLogin),
                      child: Text(_isLogin ? 'حساب نداری؟ ثبت‌نام کن' : 'حساب داری؟ وارد شو'),
                    ),
                    // ⚠️ اعتبارنامه پیش‌فرض ادمین عمداً نمایش داده نمی‌شود
                    // (قبلاً admin / 1234 روی همین صفحه چاپ می‌شد).
                    // اگر حساب ادمین هنوز ساخته نشده، در اولین ورود با اعتبارنامه
                    // پیش‌فرض (مستند در README داخلی/متغیرهای config) ساخته می‌شود
                    // و بلافاصله باید از پنل عوض شود.
                  ]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
