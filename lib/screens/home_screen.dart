import 'package:flutter/material.dart';
import '../theme/qand_theme.dart';
import '../data/demo_products.dart';
import '../models/product.dart';
import '../services/auth_service.dart';
import '../services/cart_service.dart';
import '../services/product_repository.dart';
import '../services/push_service.dart';
import '../widgets/product_image.dart';
import 'cart_screen.dart';
import 'custom_cake_screen.dart';
import 'product_detail_screen.dart';
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
  int _selected = 0;
  int _tab = 0;
  bool _isAdmin = false;
  // لیست محصولات: پیش‌فرض دمو تا سوپابیس جواب بده؛ هیچ‌وقت خالی نمی‌ماند
  List<Product> _products = demoProducts;
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
    // محصولات سرور — بدون بلاک کردن UI
    ProductRepository().loadActiveWithSource().then((r) {
      if (!mounted) return;
      setState(() {
        // فروشگاه واقعی (حتی خالی) را نشان بده؛ دمو فقط وقتی که آفلاین/خطا هستیم
        _products = r.products;
        _supabaseEmpty = r.source == ProductSource.supabaseEmpty;
        if (_products.isNotEmpty) {
          _selected = _selected.clamp(0, _products.length - 1);
        }
      });
    });
  }

  // وقتی لیست خالی است (فروشگاه سوپابیسی خالی) current استفاده نمی‌شود؛
  // ولی برای اطمینان از نبود ArgumentError در clamp، fallback دمو می‌دهیم.
  Product get current => _products.isEmpty
      ? demoProducts.first
      : _products[_selected.clamp(0, _products.length - 1)];

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
              ? const ChatScreen(showBackButton: false)
              : AdminScreen(username: widget.username),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 16)]),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _nav(Icons.home, 0),
            _nav(Icons.receipt_long, 1),
            _nav(Icons.chat_bubble_outline, 2),
            if (_isAdmin) _nav(Icons.admin_panel_settings_outlined, 3),
            IconButton(onPressed: _logout, icon: const Icon(Icons.logout, color: Colors.grey)),
          ],
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
    return SingleChildScrollView(
      child: Column(children: [
        Container(
          decoration: QandTheme.headerGradient(),
          padding: const EdgeInsets.fromLTRB(20, 56, 20, 130),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('سلام ${widget.username} 👋', style: const TextStyle(color: Colors.white, fontSize: 18)),
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
            const Text('امروز چی برات بپزم؟', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            Image.asset('assets/images/chef.png', height: 190, errorBuilder: (_, __, ___) =>
              Container(height: 190, width: 190, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: const Center(child: Text('👩‍🍳', style: TextStyle(fontSize: 90))))),
          ]),
        ),
        Transform.translate(
          offset: const Offset(0, -90),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(children: [
                  const Text('یکی رو انتخاب کن', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 118,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      reverse: true,
                      itemCount: _products.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (_, i) {
                        final p = _products[i];
                        final on = i == _selected;
                        return GestureDetector(
                          onTap: () => setState(() => _selected = i),
                          child: Column(children: [
                            Container(
                              width: on ? 76 : 66, height: on ? 76 : 66,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: on ? QandTheme.red : Colors.grey.shade200, width: on ? 3 : 1),
                                color: QandTheme.cream,
                              ),
                              child: ClipOval(
                                child: ProductImage(
                                  asset: p.asset,
                                  imageUrl: p.imageUrl,
                                  width: on ? 76 : 66,
                                  height: on ? 76 : 66,
                                  fit: BoxFit.cover,
                                  iconSize: 28,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(p.title, style: TextStyle(fontSize: 12, fontWeight: on ? FontWeight.bold : FontWeight.normal, color: on ? QandTheme.red : Colors.black87)),
                          ]),
                        );
                      },
                    ),
                  ),
                  if (_supabaseEmpty)
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(20)),
                      child: const Text('🛒 فعلاً محصولی برای فروش فعال نیست؛ بعداً سر بزن.', style: TextStyle(fontSize: 13)),
                    ),
                  if (!_supabaseEmpty) ...[
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(color: QandTheme.cream, borderRadius: BorderRadius.circular(20)),
                      child: Text('✨ ${current.title} تازه و خونگی', style: const TextStyle(fontSize: 13)),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => ProductDetailScreen(
                                    product: current,
                                    username: widget.username))).then(
                            (_) => _refreshCartCount()),
                        child: const Text('ادامه'),
                      ),
                    ),
                    const SizedBox(height: 8),
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
                  ],
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Future<void> _logout() async {
    await AuthService().logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const AuthScreen()), (_) => false);
  }
}
