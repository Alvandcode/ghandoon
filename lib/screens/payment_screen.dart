import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/qand_theme.dart';
import '../models/order.dart';
import '../services/order_service.dart';
import '../services/receipt_service.dart';
import '../services/settings_service.dart';
import '../utils/format.dart';

class PaymentScreen extends StatefulWidget {
  final QandOrder order;
  const PaymentScreen({super.key, required this.order});
  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String _card = '';
  String _owner = '';
  String _zarin = '';
  String? _receipt;
  bool _sending = false;
  // نسخه تازه سفارش (مبلغ ممکن است بعد از ورود به این صفحه توسط مدیر اعلام شود)
  late QandOrder _order;
  bool _orderGone = false;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    _receipt = widget.order.receiptPath;
    SettingsService().load().then((m) {
      if (!mounted) return;
      setState(() {
        _card = m['card'] ?? '';
        _owner = m['owner'] ?? '';
        _zarin = m['zarin'] ?? '';
      });
    });
    // رفرش مبلغ/وضعیت از حافظه لوکال تا اگر مدیر همین حالا مبلغ را ثبت کرد،
    // کاربر مبلغ قدیمی (تخمینی) را نبیند و با مبلغ اشتباه واریز نکند.
    OrderService().byId(widget.order.id).then((fresh) {
      if (!mounted) return;
      if (fresh == null) {
        setState(() => _orderGone = true);
        return;
      }
      setState(() {
        _order = fresh;
        _receipt = fresh.receiptPath ?? _receipt;
      });
    });
  }

  /// فقط نام فایل (نه مسیر کامل) تا مسیر خصوصی دستگاه لو نرود
  String _baseName(String path) {
    final p = path.replaceAll('\\', '/');
    final i = p.lastIndexOf('/');
    return i >= 0 ? p.substring(i + 1) : p;
  }

  bool _isUrl(String s) => s.startsWith('http://') || s.startsWith('https://');

  Future<void> _pickReceipt() async {
    if (_sending) return;
    // در وضعیت pending هنوز مبلغی اعلام نشده؛ ارسال فیش زودهنگام جلوی خطا را می‌گیرد
    if (_order.status == OrderStatuses.pending) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('هنوز مبلغ توسط مدیر اعلام نشده؛ لطفا صبر کن 🙏')));
      return;
    }
    if (_order.status == OrderStatuses.cancelled) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('این سفارش لغو شده است')));
      return;
    }
    setState(() => _sending = true);
    try {
      final img = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (img == null) return;
      // اگر سفارش از مرحله فیش گذشته (تایید/آماده/تحویل)، ارسال مجدد نباید
      // وضعیت را به عقب برگرداند؛ فقط فایل جدید ذخیره شود.
      const beyond = {
        OrderStatuses.approved,
        OrderStatuses.ready,
        OrderStatuses.delivered,
      };
      final newStatus =
          beyond.contains(_order.status) ? _order.status : OrderStatuses.receiptSent;
      // اول آپلود به Storage (اگر آنلاین) تا مدیر روی گوشی خودش فیش را ببیند؛
      // آفلاین همان مسیر لوکال برمی‌گردد و چیزی گم نمی‌شود.
      final storedPath = await ReceiptService().uploadReceipt(
        localPath: img.path,
        orderId: _order.id,
        username: _order.owner,
      );
      await OrderService()
          .updateStatus(_order.id, newStatus, receiptPath: storedPath);
      final fresh = await OrderService().byId(_order.id);
      if (!mounted) return;
      if (fresh != null) _order = fresh;
      setState(() => _receipt = storedPath);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فیش ارسال شد، منتظر تایید مدیر باش 🙏')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('انتخاب عکس ناموفق بود؛ دسترسی گالری را بررسی کن')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _openZarinpal() async {
    final uri = Uri.tryParse(_zarin.trim());
    // فقط https — http برای درگاه پرداخت ریسک MITM دارد
    if (uri == null || uri.scheme != 'https') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لینک پرداخت معتبر نیست (باید https باشد)')));
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('باز کردن لینک پرداخت ممکن نشد')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_orderGone) {
      return Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(90),
          child: Container(decoration: QandTheme.headerGradient(radius: 24),
            child: SafeArea(child: Row(children: [
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_forward, color: Colors.white)),
              const Text('پرداخت و فیش', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
            ]))),
        ),
        body: const Center(child: Text('این سفارش پیدا نشد (شاید حذف شده). برگرد و لیست را رفرش کن.')),
      );
    }
    final isPending = _order.status == OrderStatuses.pending;
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(90),
        child: Container(decoration: QandTheme.headerGradient(radius: 24),
          child: SafeArea(child: Row(children: [
            IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_forward, color: Colors.white)),
            const Text('پرداخت و فیش', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
          ]))),
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (isPending)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(16)),
            child: const Text('⏳ هنوز مبلغ نهایی توسط مدیر اعلام نشده. لطفا واریز نکن تا مبلغ دقیق مشخص شود.',
                style: TextStyle(fontSize: 13)),
          ),
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_order.productTitle, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
          if (_order.itemsSummary.isNotEmpty)
            Text(_order.itemsSummary, style: const TextStyle(fontSize: 13)),
          if (_order.cakeOptions.isNotEmpty)
            Text('🎂 ${_order.cakeOptions}',
                style: const TextStyle(fontSize: 13)),
          Text(
            isPending
                ? 'مبلغ تقریبی: ${formatToman(_order.totalPrice)} (نهایی را مدیر اعلام می‌کند)'
                : 'مبلغ اعلامی مدیر: ${formatToman(_order.totalPrice)}',
            style: const TextStyle(fontWeight: FontWeight.bold, color: QandTheme.red, fontSize: 16),
          ),
          if (_order.deliveryFee > 0)
            Text('شامل هزینه پیک: ${formatToman(_order.deliveryFee)}',
                style: const TextStyle(fontSize: 12, color: Colors.black54)),
          Text(
              'تحویل: ${Fulfillment.fa(_order.fulfillment)} | وضعیت: ${OrderStatuses.fa(_order.status)}'),
        ]))),
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('کارت‌به‌کارت', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          // شماره کارت حتما چپ‌به‌راست تا در محیط RTL برعکس دیده نشود
          Directionality(
            textDirection: TextDirection.ltr,
            child: SelectableText(_card.isEmpty ? '...' : _card,
                textAlign: TextAlign.left,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1)),
          ),
          Text('به نام $_owner'),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: _card.isEmpty ? null : () {
              // کپی فقط ارقام انگلیسی تا در اپ بانکی بدون خط‌تیره پیست شود
              final digits = _card.replaceAll(RegExp(r'[^0-9]'), '');
              Clipboard.setData(ClipboardData(text: digits.isEmpty ? _card : digits));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('شماره کارت کپی شد')));
            }, icon: const Icon(Icons.copy), label: const Text('کپی شماره کارت'))),
          ]),
          if (_zarin.isNotEmpty) ...[
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _openZarinpal,
              icon: const Icon(Icons.credit_card),
              label: const Text('پرداخت آنلاین (زرین‌پال)'),
            ),
          ] else const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('پرداخت آنلاین به‌زودی فعال می‌شود.', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ),
        ]))),
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('فیش واریزی', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _receiptPreview(),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _sending ? null : _pickReceipt,
            icon: _sending
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.upload),
            label: Text(_sending ? 'در حال ارسال...' : (_receipt == null ? 'انتخاب و ارسال فیش' : 'ارسال مجدد فیش')),
          ),
        ]))),
      ]),
    );
  }

  Widget _receiptPreview() {
    if (_receipt == null) {
      return const Text('هنوز فیشی نفرستادی', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey));
    }
    final path = _receipt!;
    final Widget img;
    if (_isUrl(path)) {
      // مسیر سوپابیسی (آینده) — با کش نمایش بده
      img = CachedNetworkImage(
        imageUrl: path,
        height: 220,
        width: double.infinity,
        fit: BoxFit.cover,
        placeholder: (_, __) => const SizedBox(
            height: 220, child: Center(child: CircularProgressIndicator())),
        errorWidget: (_, __, ___) => const Padding(
          padding: EdgeInsets.all(12),
          child: Icon(Icons.receipt_long, size: 64, color: QandTheme.red),
        ),
      );
    } else {
      final file = File(path);
      img = Image.file(
        file,
        height: 220,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Padding(
          padding: EdgeInsets.all(12),
          child: Icon(Icons.receipt_long, size: 64, color: QandTheme.red),
        ),
      );
    }
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: img,
        ),
        const SizedBox(height: 6),
        Text(_baseName(path),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}
