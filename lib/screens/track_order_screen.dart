import 'package:flutter/material.dart';
import '../theme/qand_theme.dart';
import '../models/order.dart';
import '../services/notification_service.dart';
import '../services/order_service.dart';
import '../utils/format.dart';
import 'payment_screen.dart';
import 'chat_screen.dart';

class TrackOrderScreen extends StatefulWidget {
  final String username;
  const TrackOrderScreen({super.key, required this.username});
  @override
  State<TrackOrderScreen> createState() => _TrackOrderScreenState();
}

class _TrackOrderScreenState extends State<TrackOrderScreen> {
  List<QandOrder> _orders = [];
  bool _loading = true;
  // خط‌مبنای وضعیت‌ها برای اعلان تغییر (رفرش اول فقط ثبت می‌شود).
  Map<String, String> _knownStatus = {};
  bool _baselineDone = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final orders = await OrderService().all(forUser: widget.username);
    final changed = _baselineDone
        ? OrderChangeDetector.statusChangedFromMap(
            oldStatus: _knownStatus,
            newList: orders,
          )
        : <QandOrder>[];
    if (!mounted) return;
    setState(() {
      _orders = orders.reversed.toList();
      _loading = false;
      _knownStatus = {for (final o in orders) o.id: o.status};
      _baselineDone = true;
    });
    for (final o in changed) {
      // ignore: unawaited_futures
      NotificationService().showStatusChanged(o);
    }
  }

  Future<void> _cancel(QandOrder o) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('لغو سفارش؟'),
        content: Text('سفارش ${o.displayCode} لغو شود؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('نه')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('بله، لغو کن')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final res = await OrderService().cancelByUser(o.id, widget.username);
    if (!mounted) return;
    String msg;
    switch (res) {
      case OrderService.updateOk:
        msg = 'سفارش لغو شد';
      case OrderService.cancelForbidden:
        msg = 'این سفارش مال تو نیست';
      case OrderService.cancelNotAllowed:
        msg = 'این سفارش دیگر قابل لغو نیست (با مدیر تماس بگیر)';
      default:
        msg = 'لغو ناموفق بود';
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(90),
        child: Container(decoration: QandTheme.headerGradient(radius: 24),
          child: const SafeArea(child: Center(child: Text('پیگیری سفارش‌ها', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17))))),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _orders.isEmpty
              ? const Center(child: Text('هنوز سفارشی ثبت نکردی 🍰\nاز صفحه اصلی یک محصول انتخاب کن.'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(14),
                    itemCount: _orders.length,
                    itemBuilder: (_, i) => _card(_orders[i]),
                  ),
                ),
    );
  }

  Widget _card(QandOrder o) {
    final idx = OrderStatuses.flow.indexOf(o.status);
    final isCancelled = o.status == OrderStatuses.cancelled;
    final isPending = o.status == OrderStatuses.pending;
    // تا مدیر مبلغ را اعلام نکرده، پرداخت معنایی ندارد — دکمه را قفل کن
    // تا کاربر اشتباهی با مبلغ تقریبی کارت‌به‌کارت نکند.
    final canPay = !isPending && !isCancelled;
    final canCancel = isPending || o.status == OrderStatuses.awaitingPayment;
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Expanded(child: Text(o.productTitle, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: o.status == OrderStatuses.cancelled ? Colors.red.shade50 : Colors.green.shade50, borderRadius: BorderRadius.circular(12)),
              child: Text(OrderStatuses.fa(o.status), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
          ]),
          const SizedBox(height: 6),
          Text('تعداد: ${o.qty} | نفرات: ${o.persons} | تحویل: ${o.deliveryDate}', style: const TextStyle(fontSize: 13, color: Colors.black54)),
          Text('${Fulfillment.fa(o.fulfillment)}${o.isPickup ? '' : ' | هزینه پیک: ${formatToman(o.deliveryFee)}'}',
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
          Text('آدرس: ${o.address}', style: const TextStyle(fontSize: 13, color: Colors.black54)),
          if (o.itemsSummary.isNotEmpty)
            Text('اقلام: ${o.itemsSummary}',
                style: const TextStyle(fontSize: 12, color: Colors.black54)),
          if (o.cakeOptions.isNotEmpty)
            Text('🎂 ${o.cakeOptions}',
                style: const TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 4),
          SelectableText('کد پیگیری: ${o.displayCode}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          // تایم‌لاین ساده (برای لغوشده خاکستری کامل)
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (var s = 0; s < OrderStatuses.flow.length; s++)
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (!isCancelled && idx >= 0 && s <= idx) ? QandTheme.red : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(10)),
                child: Text(OrderStatuses.fa(OrderStatuses.flow[s]).split('،').first,
                  style: TextStyle(fontSize: 10, color: (!isCancelled && idx >= 0 && s <= idx) ? Colors.white : Colors.black54))),
          ]),
          const SizedBox(height: 10),
          if (isPending)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(12)),
              child: const Text('⏳ سفارشت ثبت شد؛ منتظر اعلام مبلغ توسط مدیر باش. بعد از اعلام، دکمه پرداخت فعال می‌شود.',
                  style: TextStyle(fontSize: 12)),
            ),
          Row(children: [
            Expanded(
              child: ElevatedButton(
                onPressed: canPay
                    ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => PaymentScreen(order: o))).then((_) => _load())
                    : null,
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                child: Text(isCancelled
                    ? 'لغو شده'
                    : isPending
                        ? 'منتظر اعلام مبلغ...'
                        : 'پرداخت / ارسال فیش'),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          ChatScreen(username: widget.username))),
              icon: const Icon(Icons.support_agent),
              tooltip: 'ارتباط با مدیر',
            ),
          ]),
          if (canCancel)
            TextButton.icon(
              onPressed: () => _cancel(o),
              icon: const Icon(Icons.cancel_outlined, size: 18),
              label: const Text('لغو سفارش'),
            ),
        ]),
      ),
    );
  }
}
