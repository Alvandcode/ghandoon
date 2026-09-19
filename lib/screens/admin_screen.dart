import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../theme/qand_theme.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../models/chat_message.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/notification_service.dart';
import '../services/order_service.dart';
import '../services/settings_service.dart';
import '../services/product_repository.dart';
import '../services/supabase_service.dart';
import '../data/demo_products.dart';
import '../utils/format.dart';
import 'chat_screen.dart';
import 'product_edit_screen.dart';

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
  bool _usingDefaultPass = false;
  // برای اعلان سفارش جدید: اولین بار فقط خط‌مبنا، بعدش تفاوت‌ها اعلان می‌شوند.
  bool _ordersBaselineDone = false;
  Set<String> _knownOrderIds = {};
  List<ChatConversation> _convos = [];
  final _card = TextEditingController();
  final _owner = TextEditingController();
  final _zarin = TextEditingController();
  final _price = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
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
    final usingDefault = admin ? await AuthService().isUsingDefaultAdminPassword() : false;
    final repoMsgs = admin ? await ChatService().allForAdmin() : <ChatMessage>[];
    // اعلان سفارش‌های جدید (فقط از دومین بار به بعد تا باز شدن اول اسپم نشود)
    final freshIds = {for (final o in orders) o.id};
    final isRefresh = _ordersBaselineDone;
    final newOnes = isRefresh
        ? orders.where((o) => !_knownOrderIds.contains(o.id)).toList()
        : <QandOrder>[];
    if (!mounted) return;
    setState(() {
      _orders = orders.reversed.toList();
      _isAdmin = admin;
      _usingDefaultPass = usingDefault;
      _knownOrderIds = freshIds;
      _ordersBaselineDone = true;
      _convos = groupConversations(repoMsgs, ChatService.adminName);
      _card.text = s['card'] ?? '';
      _owner.text = s['owner'] ?? '';
      _zarin.text = s['zarin'] ?? '';
      // لیست واقعی (حتی خالی) — تا مدیر بفهمد فروشگاه واقعا خالی است نه دمو
      _products = prods.products;
    });
    for (final o in newOnes) {
      // ignore: unawaited_futures
      NotificationService().showNewOrder(o);
    }
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

  Future<void> _delete(QandOrder o) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف سفارش؟'),
        content: Text('سفارش ${o.displayCode} برای همیشه حذف شود؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('نه')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('بله، حذف کن')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final ok = await OrderService().deleteOrder(o.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? 'حذف شد' : 'حذف ناموفق بود')));
    if (ok) await _load();
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
            Text('پنل مدیر قند 👩‍🍳 — ${widget.username}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            TabBar(controller: _tab, indicatorColor: Colors.white, labelColor: Colors.white, unselectedLabelColor: Colors.white70,
              tabs: const [Tab(text: 'سفارش‌ها'), Tab(text: 'پیام‌ها'), Tab(text: 'محصولات'), Tab(text: 'تنظیمات')]),
          ])),
        ),
      ),
      body: TabBarView(controller: _tab, children: [_ordersTab(), _messagesTab(), _productsTab(), _settingsTab()]),
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
            Text(
              'تحویل: ${Fulfillment.fa(o.fulfillment)}${o.isPickup ? '' : ' | پیک: ${formatToman(o.deliveryFee)}'}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            if (o.itemsSummary.isNotEmpty)
              Text('اقلام: ${o.itemsSummary}',
                  style: const TextStyle(fontSize: 12)),
            if (o.cakeOptions.isNotEmpty)
              Text('🎂 ${o.cakeOptions}',
                  style: const TextStyle(fontSize: 12)),
            Text('کاربر: ${o.owner.isEmpty ? '(قدیمی/بدون مالک)' : o.owner} | ثبت: ${o.createdAt}',
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
            SelectableText('کد پیگیری: ${o.displayCode}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            Text('وضعیت: ${OrderStatuses.fa(o.status)}', style: const TextStyle(fontWeight: FontWeight.bold, color: QandTheme.red)),
            if (o.receiptPath != null) _receiptThumb(o.receiptPath!),
            Wrap(spacing: 6, children: [
              _stBtn(o, 'مبلغ+کارت', OrderStatuses.awaitingPayment),
              _stBtn(o, 'تایید فیش', OrderStatuses.approved),
              _stBtn(o, 'آماده', OrderStatuses.ready),
              _stBtn(o, 'تحویل', OrderStatuses.delivered),
              _stBtn(o, 'لغو', OrderStatuses.cancelled),
              TextButton(
                onPressed: () => _delete(o),
                child: const Text('حذف',
                    style: TextStyle(fontSize: 12, color: Colors.red)),
              ),
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

  Widget _messagesTab() {
    if (!SupabaseService.isReady) {
      return const Center(
          child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
            'پیام‌ها فقط وقتی سوپابیس وصل است کار می‌کند.\nالان در حالت آفلاین هستی.',
            textAlign: TextAlign.center),
      ));
    }
    if (_convos.isEmpty) {
      return const Center(child: Text('هنوز پیامی از مشتری نیست 💬'));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _convos.length,
        itemBuilder: (_, i) {
          final c = _convos[i];
          final last = c.last;
          final preview = last.hasImage && last.text == '📷 عکس'
              ? '📷 عکس فرستاده'
              : last.text;
          return Card(
            child: ListTile(
              leading: const CircleAvatar(child: Text('🧑')),
              title: Text(c.peer,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                  '${last.sender == ChatService.adminName ? 'تو: ' : ''}$preview',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              trailing: Text('${c.messages.length} پیام',
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ChatScreen(
                        username: widget.username, peer: c.peer)),
              ).then((_) => _load()),
            ),
          );
        },
      ),
    );
  }

  Widget _productsTab() {
    final online = SupabaseService.isReady;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text(
            online
                ? 'لیست زنده از سرور. افزودن، ویرایش، قیمت و فعال‌بودن همین‌جا ذخیره می‌شود.'
                : 'حالت آفلاین/دمو: تغییر محصول فقط وقتی سوپابیس وصل است کار می‌کند.',
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _openProductAdd,
              icon: const Icon(Icons.add),
              label: const Text('محصول جدید ➕'),
            ),
          ),
          const SizedBox(height: 8),
          for (final p in _products)
            Card(
                child: ListTile(
              title: Text(p.title),
              subtitle: Text('${formatToman(p.price)} | ${p.category}\n${p.unit}'),
              isThreeLine: true,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'ویرایش کامل (اسم، قیمت، عکس...)',
                    onPressed: () => _openProductEdit(p),
                    icon: const Icon(Icons.edit, color: QandTheme.red),
                  ),
                  Switch(
                    value: p.isActive,
                    onChanged: (v) => _toggleProduct(p, v),
                  ),
                ],
              ),
            )),
        ],
      ),
    );
  }

  Future<void> _openProductAdd() async {
    if (!SupabaseService.isReady) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('آفلاین هستی؛ اتصال سوپابیس لازم است')));
      return;
    }
    final saved = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProductEditScreen()),
    );
    if (saved == true) await _load();
  }

  Future<void> _openProductEdit(Product p) async {
    if (!SupabaseService.isReady) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('آفلاین هستی؛ اتصال سوپابیس لازم است')));
      return;
    }
    final saved = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProductEditScreen(product: p)),
    );
    if (saved == true) await _load();
  }

  Future<void> _toggleProduct(Product p, bool v) async {
    if (!SupabaseService.isReady) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('آفلاین هستی؛ اتصال سوپابیس لازم است')));
      return;
    }
    final ok = await ProductRepository().setActive(p.id, v);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? 'وضعیت محصول عوض شد' : 'ناموفق بود')));
    if (ok) {
      setState(() {
        final i = _products.indexWhere((e) => e.id == p.id);
        if (i != -1) _products[i] = p.copyWith(isActive: v);
      });
    }
  }

  Future<void> _askChangePassword() async {
    final oldCtl = TextEditingController();
    final newCtl = TextEditingController();
    final confirmCtl = TextEditingController();
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('تغییر رمز مدیر'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: oldCtl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'رمز فعلی'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: newCtl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'رمز جدید (حداقل ۶ کاراکتر)',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: confirmCtl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'تکرار رمز جدید'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('لغو'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('تغییر رمز'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
      if (newCtl.text != confirmCtl.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تکرار رمز جدید مطابقت ندارد')),
        );
        return;
      }
      final res = await AuthService().changePassword(
        username: widget.username,
        oldPassword: oldCtl.text,
        newPassword: newCtl.text,
      );
      if (!mounted) return;
      String msg;
      switch (res) {
        case AuthService.changeOk:
          msg = 'رمز با موفقیت عوض شد ✅';
        case AuthService.changeWrongOld:
          msg = 'رمز فعلی اشتباه است';
        case AuthService.changeWeakNew:
          msg = 'رمز جدید باید حداقل ۶ کاراکتر باشد';
        case AuthService.changeSameAsOld:
          msg = 'رمز جدید باید با قبلی فرق کند';
        default:
          msg = 'تغییر رمز ناموفق بود';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      if (res == AuthService.changeOk) await _load();
    } finally {
      oldCtl.dispose();
      newCtl.dispose();
      confirmCtl.dispose();
    }
  }

  Widget _settingsTab() {
    return ListView(padding: const EdgeInsets.all(16), children: [
      if (_usingDefaultPass)
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: const Text(
            '⚠️ هنوز با رمز پیش‌فرض (admin / 1234) وارد می‌شوی! همین حالا از دکمه «تغییر رمز مدیر» رمز را عوض کن.',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ),
      OutlinedButton.icon(
        onPressed: _askChangePassword,
        icon: const Icon(Icons.lock_reset),
        label: const Text('تغییر رمز مدیر'),
      ),
      const SizedBox(height: 14),
      const Text('شماره کارت و زرین‌پال — ذخیره برای همه کاربران اعمال می‌شود ✅', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
        // ذخیره واقعی: اول سرور (همه کاربران می‌بینند)، بعد آینه لوکال.
        final ok = await SettingsService().save(
            card: _card.text.trim(), owner: owner, zarin: zarin);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok
              ? 'برای همه کاربران ذخیره شد ✅'
              : 'فقط روی همین گوشی ذخیره شد (سرور در دسترس نیست یا دسترسی‌اش باز نشده — دستور دسترسی‌ها را در سوپابیس اجرا کن)'),
        ));
      }, child: const Text('ذخیره تنظیمات')),
    ]);
  }
}
