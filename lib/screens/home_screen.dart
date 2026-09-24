import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../theme/qand_theme.dart';
import '../services/auth_service.dart';
import '../services/cart_service.dart';
import '../services/product_repository.dart';
import '../services/push_service.dart';
import '../services/settings_service.dart';
import '../utils/responsive.dart';
import '../widgets/safe_scaffold.dart';
import 'cart_screen.dart';
import 'category_products_screen.dart';
import 'custom_cake_screen.dart';
import 'track_order_screen.dart';
import 'chat_screen.dart';
import 'admin_screen.dart';
import 'auth_screen.dart';

class HomeScreen extends StatefulWidget {
  final String username;
  const HomeScreen({super.key, required this.username});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  bool _isAdmin = false;
  // چهار شاخه اصلی سفارش — از تنظیمات مدیر (قابل ویرایش)
  List<String> _mainCategories = List.of(AppConfig.defaultMainCategories);
  // «سوپابیس وصل است ولی فروشگاه خالی» — جدا از حالت آفلاین
  bool _supabaseEmpty = false;
  int _cartCount = 0;

  @override
  void initState() {
    super.initState();
    // نقش فقط از AuthService (نه مقایسه رشته username) تا با دست‌کاری
    // آرگومان HomeScreen نتوان نقش مدیر را جعل کرد.
    AuthService().isAdmin().then((v) async {
      if (!mounted) return;
      setState(() => _isAdmin = v);
      // پوش: عضویت در تاپیک شخصی (+ تاپیک مدیران)؛ بدون فایربیس false
      // می‌دهد و اپ با همان اعلان محلی ادامه می‌دهد.
      await PushService()
          .init(username: widget.username, isAdmin: v)
          .catchError((_) => false);
      _drainPushTap();
    });
    _refreshCartCount();
    _loadMainCategories();
    // محصولات سرور — بدون بلاک کردن UI (برای تشخیص فروشگاه خالی)
    ProductRepository().loadActiveWithSource().then((r) {
      if (!mounted) return;
      setState(() {
        _supabaseEmpty = r.source == ProductSource.supabaseEmpty;
      });
    });
  }

  Future<void> _loadMainCategories() async {
    final cats = await SettingsService().loadMainCategories();
    if (!mounted) return;
    setState(() => _mainCategories = cats);
  }

  Future<void> _refreshCartCount() async {
    final n = await CartService().count(widget.username);
    if (!mounted) return;
    setState(() => _cartCount = n);
  }

  Future<void> _openCart() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CartScreen(username: widget.username)),
    );
    _refreshCartCount();
  }

  /// اگر اپ با زدن روی اعلان باز شده باشد، به تب درست می‌رویم.
  void _drainPushTap() {
    final id = PushService().consumeTap();
    if (id == null || !mounted) return;
    setState(() => _tab = _isAdmin ? 3 : 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _tab == 0 ? _homeBody() : _tab == 1
          ? TrackOrderScreen(username: widget.username)
          : _tab == 2
              ? ChatScreen(
                  username: widget.username, showBackButton: false)
              : AdminScreen(username: widget.username),
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 16)]),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _nav(Icons.home, 0),
              _nav(Icons.receipt_long, 1),
              // چت پایین صفحه فقط برای مشتری است؛ مدیر «تب پیام‌ها» را در پنل دارد.
              // (قبلاً برای مدیر گفتگوی خالی با خودش باز می‌شد)
              if (!_isAdmin) _nav(Icons.chat_bubble_outline, 2),
              if (_isAdmin) _nav(Icons.admin_panel_settings_outlined, 3),
              IconButton(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _nav(IconData ic, int i) {
    final on = _tab == i;
    return IconButton(
      onPressed: () {
        setState(() => _tab = i);
        _drainPushTap();
      },
      icon: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: on ? QandTheme.red : Colors.transparent, shape: BoxShape.circle),
        child: Icon(ic, color: on ? Colors.white : Colors.grey),
      ),
    );
  }

  Widget _homeBody() {
    final width = MediaQuery.sizeOf(context).width;
    final topPad = topSafeOnly(context, extra: 40);
    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: bottomSafeOnly(context, extra: 90)),
      child: Column(children: [
        Container(
          decoration: QandTheme.headerGradient(),
          padding: EdgeInsets.fromLTRB(20, topPad, 20, 100),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Expanded(
                child: Text('سلام ${widget.username} 👋',
                    style:
                        const TextStyle(color: Colors.white, fontSize: 18),
                    overflow: TextOverflow.ellipsis),
              ),
              Row(children: [
                // سبد خرید با نشان تعداد
                Stack(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.white24,
                      child: IconButton(
                        tooltip: 'سبد خرید',
                        onPressed: _openCart,
                        icon: const Icon(Icons.shopping_cart_outlined,
                            color: Colors.white),
                      ),
                    ),
                    if (_cartCount > 0)
                      Positioned(
                        left: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                              color: Colors.white, shape: BoxShape.circle),
                          child: Text('$_cartCount',
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: QandTheme.red)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 8),
                // دکمه اعلان قبلاً هیچ کاری نمی‌کرد؛ حالا به تب پیگیری می‌رود.
                CircleAvatar(
                  backgroundColor: Colors.white24,
                  child: IconButton(
                    tooltip: 'پیگیری سفارش‌ها',
                    onPressed: () => setState(() => _tab = 1),
                    icon: const Icon(Icons.notifications_none,
                        color: Colors.white),
                  ),
                ),
              ]),
            ]),
            const SizedBox(height: 6),
            const Text('امروز چی برات بپزم؟',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            // لوگوی دایره‌ای قندون — اندازه با عرض صفحه تنظیم می‌شود.
            Builder(builder: (context) {
              final s = Responsive.badge(width, min: 120, max: 190, ratio: 0.46);
              return ClipOval(
                child: Image.asset(
                  'assets/images/chef.png',
                  height: s,
                  width: s,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: s,
                    width: s,
                    decoration: const BoxDecoration(
                        color: Colors.white, shape: BoxShape.circle),
                    child: Center(
                      child: Text('👩‍🍳',
                          style: TextStyle(fontSize: s * 0.45)),
                    ),
                  ),
                ),
              );
            }),
          ]),
        ),
        Transform.translate(
          offset: const Offset(0, -70),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: Responsive.hPad(width)),
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(Responsive.hPad(width, normal: 18, narrow: 14)),
                child: Column(children: [
                  const Text('کدوم شاخه رو می‌خوای؟',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  const Text('یک دسته اصلی رو انتخاب کن تا محصولاتش رو ببینی',
                      style: TextStyle(fontSize: 12, color: Colors.black54)),
                  const SizedBox(height: 12),
                  _categoryGrid(width),
                  if (_supabaseEmpty)
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(20)),
                      child: const Text(
                          '🛒 فعلاً محصولی برای فروش فعال نیست؛ بعداً سر بزن.',
                          style: TextStyle(fontSize: 13)),
                    ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => CustomCakeScreen(
                                  username: widget.username))).then(
                          (_) => _refreshCartCount()),
                      icon: const Icon(Icons.cake),
                      label: const Text('کیک تولد سفارشی بساز 🎂'),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  /// چهار کارت شاخه اصلی سفارش (۲×۲) — هر کدام به لیست محصولاتش می‌رود.
  Widget _categoryGrid(double width) {
    final crossAxis = width < 360 ? 2 : 2;
    final aspect = width < 360 ? 1.05 : 1.15;
    return GridView.count(
      crossAxisCount: crossAxis,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: aspect,
      children: [
        for (var i = 0; i < _mainCategories.length; i++)
          _categoryCard(_mainCategories[i], i),
      ],
    );
  }

  Widget _categoryCard(String title, int index) {
    final icons = [
      Icons.icecream_outlined,
      Icons.bakery_dining_outlined,
      Icons.cake_outlined,
      Icons.cookie_outlined,
    ];
    final emojis = ['🍮', '🥐', '🎂', '🍫'];
    return Material(
      color: QandTheme.cream,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CategoryProductsScreen(
              category: title,
              username: widget.username,
            ),
          ),
        ).then((_) => _refreshCartCount()),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: QandTheme.red, width: 2),
                ),
                child: Center(
                  child: Text(emojis[index % emojis.length],
                      style: const TextStyle(fontSize: 26)),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 2),
              Icon(icons[index % icons.length],
                  size: 16, color: QandTheme.red),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('خروج از حساب؟'),
        content: const Text('مطمئنی می‌خوای خارج شی؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('نه، بمونم')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('بله، خارج شو')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await AuthService().logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const AuthScreen()), (_) => false);
  }
}
