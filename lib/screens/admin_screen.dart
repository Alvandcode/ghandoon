import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../theme/qand_theme.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../services/auth_service.dart';
import '../services/order_service.dart';
import '../services/settings_service.dart';
import '../services/product_repository.dart';
import '../services/supabase_service.dart';
import '../data/demo_products.dart';
import '../utils/format.dart';

class AdminScreen extends StatefulWidget {
  final String username;
  const AdminScreen({super.key, required this.username});
  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<QandOrder> _orders = [];
  List<Product> _products = demoProducts;
  bool _isAdmin = false;
  final _card = TextEditingController();
  final _owner = TextEditingController();
  final _zarin = TextEditingController();
  final _price = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    _card.dispose();
    _owner.dispose();
    _zarin.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final admin = await AuthService().isAdmin();
    final orders = await OrderService().all(isAdmin: admin);
    final s = await SettingsService().load();
    final prods = await ProductRepository().loadActiveWithSource();
    if (!mounted) return;
    setState(() {
      _orders = orders.reversed.toList();
      _isAdmin = admin;
      _card.text = s['card'] ?? '';
      _owner.text = s['owner'] ?? '';
      _zarin.text = s['zarin'] ?? '';
      // لیست واقعی (حتی خالی) — تا مدیر بفهمد فروشگاه واقعا خالی است نه دمو
      _products = prods.products;
    });
  }

  Future<void> _setStatus(QandOrder o, String st) async {
    int? price;
    if (st == OrderStatuses.awaitingPayment) {
      price = await _askPrice(o.totalPrice);
      if (price == null) return;
    }
    final res = await OrderService().updateStatus(o.id, st, totalPrice: price);
    if (!mounted) return;
    String msg;
    switch (res) {
      case OrderService.updateOk:
        msg = 'وضعیت سفارش به‌روز شد ✅';
      case OrderService.updateNotFound:
        msg = 'سفارش پیدا نشد (شاید حذف شده)';
      case OrderService.updateBadPrice:
        msg = 'مبلغ نامعتبر است؛ ثبت نشد';
      case OrderService.updateBadStatus:
        msg = 'وضعیت نامعتبر است؛ ثبت نشد';
      default:
        msg = 'به‌روزرسانی ناموفق بود';
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    if (res != OrderService.updateOk) return;
    await _load();
  }

  Future<int?> _askPrice(int current) async {
    _price.text = '$current';
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('مبلغ نهایی (تومان)'),
        content: TextField(controller: _price, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: 'مثلا 450000')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('لغو')),
          ElevatedButton(onPressed: () => Navigator.pop(context, _price.text.trim()), child: const Text('ثبت + ارسال به کاربر')),
        ],
      ),
    );
    if (result == null) return null;
    final v = parsePrice(result);
    if (v == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('مبلغ نامعتبر است (بین ۱٬۰۰۰ تا ۱٬۰۰۰٬۰۰۰٬۰۰۰ تومان)')));
    }
    return v;
  }

  @override
  Widget build(BuildContext context) {
    // فقط نقش واقعی مدیر (نه username) — جلوگیری از جعل با ساخت دستی AdminScreen
    if (!_isAdmin) {
      return const Scaffold(body: Center(child: Text('فقط مدیر دسترسی دارد 🔒')));
    }
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(140),
        child: Container(
          decoration: QandTheme.headerGradient(radius: 24),
          child: SafeArea(child: Column(children: [
            Text('پنل مدیر قند 👩‍🍳 — ${widget.username}', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            TabBar(controller: _tab, indicatorColor: Colors.white, labelColor: Colors.white, unselectedLabelColor: Colors.white70,
              tabs: const [Tab(text: 'سفارش‌ها'), Tab(text: 'محصولات'), Tab(text: 'تنظیمات')]),
          ])),
        ),
      ),
      body: TabBarView(controller: _tab, children: [_ordersTab(), _productsTab(), _settingsTab()]),
    );
  }

  Widget _ordersTab() {
    if (_orders.isEmpty) return const Center(child: Text('سفارشی نیست'));
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _orders.length,
      itemBuilder: (_, i) {
        final o = _orders[i];
        return Card(margin: const EdgeInsets.only(bottom: 10), child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${o.productTitle} × ${o.qty}', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('${o.fullName} | ${o.phone}\n${o.address}\nتحویل: ${o.deliveryDate} | مبلغ: ${formatToman(o.totalPrice)}',
                style: const TextStyle(fontSize: 13)),
            Text('کاربر: ${o.owner.isEmpty ? '(قدیمی/بدون مالک)' : o.owner} | ثبت: ${o.createdAt}',
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
            Text('وضعیت: ${OrderStatuses.fa(o.status)}', style: const TextStyle(fontWeight: FontWeight.bold, color: QandTheme.red)),
            if (o.receiptPath != null) _receiptThumb(o.receiptPath!),
            Wrap(spacing: 6, children: [
              _stBtn(o, 'مبلغ+کارت', OrderStatuses.awaitingPayment),
              _stBtn(o, 'تایید فیش', OrderStatuses.approved),
              _stBtn(o, 'آماده', OrderStatuses.ready),
              _stBtn(o, 'تحویل', OrderStatuses.delivered),
              _stBtn(o, 'لغو', OrderStatuses.cancelled),
            ]),
          ]),
        ));
      },
    );
  }

  Widget _stBtn(QandOrder o, String t, String st) {
    return ElevatedButton(
      onPressed: () => _setStatus(o, st),
      style: ElevatedButton.styleFrom(minimumSize: const Size(0, 36), padding: const EdgeInsets.symmetric(horizontal: 10)),
      child: Text(t, style: const TextStyle(fontSize: 12)),
    );
  }

  Widget _receiptThumb(String path) {
    final isUrl = path.startsWith('http://') || path.startsWith('https://');
    final Widget thumb = isUrl
        ? CachedNetworkImage(
            imageUrl: path,
            width: 64,
            height: 64,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(
              width: 64,
              height: 64,
              color: Colors.grey.shade200,
              child: const Center(
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))),
            ),
            errorWidget: (_, __, ___) => Container(
              width: 64,
              height: 64,
              color: Colors.grey.shade200,
              child: const Icon(Icons.receipt_long, color: QandTheme.red),
            ),
          )
        : Image.file(
            File(path),
            width: 64,
            height: 64,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: 64,
              height: 64,
              color: Colors.grey.shade200,
              child: const Icon(Icons.receipt_long, color: QandTheme.red),
            ),
          );
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _showReceiptZoom(path, isUrl),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: thumb,
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(child: Text('📎 فیش ارسال شده (برای بزرگ‌نمایی لمس کن)', style: TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  /// نمایش فیش در اندازه بزرگ (قبلاً «لمس کن» نوشته بود ولی هیچ onTap وجود نداشت)
  void _showReceiptZoom(String path, bool isUrl) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog.fullscreen(
        backgroundColor: Colors.black87,
        child: Stack(children: [
          Center(
            child: InteractiveViewer(
              maxScale: 4,
              child: isUrl
                  ? CachedNetworkImage(
                      imageUrl: path,
                      fit: BoxFit.contain,
                      errorWidget: (_, __, ___) => const Padding(
                        padding: EdgeInsets.all(24),
                        child: Icon(Icons.receipt_long, size: 64, color: Colors.white),
                      ),
                    )
                  : Image.file(
                      File(path),
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Padding(
                        padding: EdgeInsets.all(24),
                        child: Icon(Icons.receipt_long, size: 64, color: Colors.white),
                      ),
                    ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: AlignmentDirectional.topEnd,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _productsTab() {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          const Text('لیست زنده محصولات (سوپابیس وصل باشد از سرور، وگرنه دمو). ویرایش قیمت/عکس از داشبورد سوپابیس > جدول products.',
              style: TextStyle(color: Colors.grey)),
          for (final p in _products)
            Card(child: ListTile(
              title: Text(p.title),
              subtitle: Text('${formatToman(p.price)} | ${p.category}\n${p.unit}'),
              isThreeLine: true,
              trailing: const Icon(Icons.image, color: QandTheme.red),
            )),
          const SizedBox(height: 8),
          const Card(
              child: Padding(
                  padding: EdgeInsets.all(14),
                  child: Text(
                      '➕ افزودن/حذف محصول: در سوپابیس > Table Editor > products ردیف اضافه کن (title, category, price, unit, description, ingredients, image_url, is_active). عکس را در Storage > product-images آپلود و لینکش را در image_url بگذار.'))),
        ],
      ),
    );
  }

  Widget _settingsTab() {
    return ListView(padding: const EdgeInsets.all(16), children: [
      const Text('شماره کارت و زرین‌پال (ذخیره فقط لوکال/دمو؛ برای همه‌ی کاربران از داشبورد سوپابیس > app_settings به‌روز کن)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      const SizedBox(height: 10),
      TextField(
          controller: _card,
          decoration: const InputDecoration(labelText: 'شماره کارت'),
          keyboardType: TextInputType.number,
          textDirection: TextDirection.ltr),
      const SizedBox(height: 10),
      TextField(controller: _owner, decoration: const InputDecoration(labelText: 'به نام')),
      const SizedBox(height: 10),
      TextField(
          controller: _zarin,
          decoration: const InputDecoration(labelText: 'لینک زرین‌پال (اختیاری، بعدا)', hintText: 'https://www.zarinpal.com/...'),
          keyboardType: TextInputType.url,
          textDirection: TextDirection.ltr),
      const SizedBox(height: 14),
      ElevatedButton(onPressed: () async {
        final digits = normalizeDigits(_card.text.trim()).replaceAll(RegExp(r'[^0-9]'), '');
        final owner = _owner.text.trim();
        final zarin = _zarin.text.trim();
        // شماره کارت خالی مجاز نیست (قبلاً خالی ذخیره می‌شد و صفحه پرداخت همه «...» نشان می‌داد)
        if (!RegExp(r'^\d{16}$').hasMatch(digits)) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('شماره کارت باید دقیقاً ۱۶ رقم باشد')));
          return;
        }
        if (owner.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('نام صاحب حساب لازم است')));
          return;
        }
        if (zarin.isNotEmpty) {
          final uri = Uri.tryParse(zarin);
          // فقط https — http برای درگاه پرداخت ریسک MITM دارد
          if (uri == null || uri.scheme != 'https') {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لینک زرین‌پال معتبر نیست (باید با https شروع شود)')));
            return;
          }
        }
        // حالت دمو/آفلاین: فقط آینه لوکال. وقتی سوپابیس وصل است سرچشمه‌ی حقیقت
        // داشبورد سوپابیس است و نوشتن از کلاینت (با anon key) از RLS رد می‌شود.
        await SettingsService().saveLocalMirror(card: _card.text.trim(), owner: owner, zarin: zarin);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(SupabaseService.isReady
              ? 'ذخیره لوکال شد؛ برای همه‌ی کاربران از داشبورد سوپابیس به‌روز کن'
              : 'ذخیره شد ✅'),
        ));
      }, child: const Text('ذخیره تنظیمات')),
    ]);
  }
}
