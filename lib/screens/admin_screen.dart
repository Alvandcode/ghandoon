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
    final prods = await ProductRepository().loadActive();
    if (!mounted) return;
    setState(() {
      _orders = orders.reversed.toList();
      _isAdmin = admin;
      _card.text = s['card'] ?? '';
      _owner.text = s['owner'] ?? '';
      _zarin.text = s['zarin'] ?? '';
      if (prods.isNotEmpty) _products = prods;
    });
  }

  Future<void> _setStatus(QandOrder o, String st) async {
    int? price;
    if (st == OrderStatuses.awaitingPayment) {
      price = await _askPrice(o.totalPrice);
      if (price == null) return;
    }
    await OrderService().updateStatus(o.id, st, totalPrice: price);
    if (!mounted) return;
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('وضعیت سفارش به‌روز شد ✅')));
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
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: thumb,
          ),
          const SizedBox(width: 8),
          const Expanded(child: Text('📎 فیش ارسال شده (برای بزرگ‌نمایی لمس کن)', style: TextStyle(fontSize: 12))),
        ],
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
      const Text('شماره کارت و زرین‌پال (از داخل اپ قابل تغییر)', style: TextStyle(fontWeight: FontWeight.bold)),
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
        final card = normalizeDigits(_card.text.trim()).replaceAll(RegExp(r'[^0-9]'), '');
        final owner = _owner.text.trim();
        final zarin = _zarin.text.trim();
        if (card.isNotEmpty && !RegExp(r'^\d{12,19}$').hasMatch(card)) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('شماره کارت باید ۱۲ تا ۱۹ رقم باشد')));
          return;
        }
        if (zarin.isNotEmpty) {
          final uri = Uri.tryParse(zarin);
          if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لینک زرین‌پال معتبر نیست (باید با https شروع شود)')));
            return;
          }
        }
        await SettingsService().save(card: _card.text.trim(), owner: owner, zarin: zarin);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ذخیره شد ✅')));
      }, child: const Text('ذخیره تنظیمات')),
    ]);
  }
}
