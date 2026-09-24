import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../theme/qand_theme.dart';
import '../models/cart_item.dart';
import '../models/order.dart';
import '../services/cart_service.dart';
import '../services/order_service.dart';
import '../utils/format.dart';
import '../utils/order_rules.dart';
import '../widgets/gradient_app_bar.dart';
import '../widgets/safe_scaffold.dart';
import 'track_order_screen.dart';

/// سبد خرید چندمحصولی + تسویه (حضوری/ارسال با هزینه پیک).
class CartScreen extends StatefulWidget {
  final String username;
  const CartScreen({super.key, required this.username});
  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _note = TextEditingController();
  List<CartItem> _items = [];
  bool _loading = true;
  bool _sending = false;
  bool _pickup = false;
  int _persons = 4;
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    _date = DateTime.now().add(const Duration(days: 1));
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    _note.dispose();
    super.dispose();
  }

  int get _itemsTotal {
    var sum = 0;
    for (final i in _items) {
      sum += i.total;
    }
    return sum;
  }

  int get _fee => deliveryFee(pickup: _pickup, itemsTotal: _itemsTotal);
  int get _grand => _itemsTotal + _fee;
  int get _lead => cartLeadDays([for (final i in _items) i.leadDays]);
  int get _totalQty {
    var n = 0;
    for (final i in _items) {
      n += i.qty;
    }
    return n;
  }

  Future<void> _load() async {
    final list = await CartService().items(widget.username);
    if (!mounted) return;
    setState(() {
      _items = list;
      _loading = false;
      final minD = minCartDate(leadDays: cartLeadDays([for (final i in list) i.leadDays]));
      if (_date.isBefore(minD)) _date = minD;
    });
  }

  Future<void> _pickDate() async {
    final minD = minCartDate(leadDays: _lead);
    final d = await showDatePicker(
      context: context,
      initialDate: _date.isBefore(minD) ? minD : _date,
      firstDate: minD,
      lastDate: DateTime(minD.year, minD.month, minD.day)
          .add(const Duration(days: 90)),
    );
    if (d != null) setState(() => _date = d);
  }

  String _jalali(DateTime d) {
    final j = Jalali.fromDateTime(d);
    return '${j.year}/${j.month.toString().padLeft(2, '0')}/${j.day.toString().padLeft(2, '0')}';
  }

  Future<void> _submit() async {
    if (_items.isEmpty || _sending) return;
    if (!_form.currentState!.validate()) return;
    if (!isValidIranMobile(_phone.text)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('شماره تماس باید مثل 09130000000 باشد')));
      return;
    }
    if (_date.isBefore(minCartDate(leadDays: _lead))) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'سبد شما حداقل $_lead روز آماده‌سازی می‌خواهد؛ تاریخ دیگری انتخاب کن 🙏')));
      return;
    }
    setState(() => _sending = true);
    try {
      final summary = _items.map((e) => e.summaryLine).join(' + ');
      final cakes = _items
          .where((e) => e.productId == 'custom-cake')
          .map((e) => e.options)
          .join(' | ');
      final order = QandOrder(
        id: '${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(1 << 32)}',
        productId: 'cart',
        productTitle: 'سبد خرید (${_items.length} قلم)',
        qty: _totalQty,
        persons: _persons,
        fullName: _name.text.trim(),
        phone: normalizeDigits(_phone.text.trim()),
        address: _pickup ? 'تحویل حضوری' : _address.text.trim(),
        deliveryDate: _jalali(_date),
        note: _note.text.trim(),
        status: OrderStatuses.pending,
        totalPrice: _grand,
        createdAt: DateTime.now().toIso8601String(),
        owner: widget.username,
        trackingCode: generateTrackingCode(),
        fulfillment: _pickup ? Fulfillment.pickup : Fulfillment.delivery,
        deliveryFee: _fee,
        itemsSummary: summary,
        cakeOptions: cakes,
      );
      final saved = await OrderService().add(order);
      await CartService().clear(widget.username);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text('سفارش سبد ثبت شد 🌸 کد پیگیری: ${saved.displayCode}')));
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) => TrackOrderScreen(username: widget.username)),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GradientAppBar.of(context, title: 'سبد خرید 🛒'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? Center(
                  child: Padding(
                    padding: bottomSafePadding(context, base: 24),
                    child: const Text(
                        'سبدت خالیه 🧺\nاز صفحه اصلی محصول انتخاب کن.',
                        textAlign: TextAlign.center),
                  ),
                )
              : Form(
                  key: _form,
                  child: ListView(
                      padding: bottomSafePadding(context),
                      children: [
                    for (final item in _items) _itemCard(item),
                    const SizedBox(height: 8),
                    _fulfillmentCard(),
                    _field(_name, 'نام و نام خانوادگی', Icons.person,
                        need: true, minLen: 3, maxLen: 80),
                    _field(_phone, 'شماره تماس (09...)', Icons.phone,
                        kb: TextInputType.phone, need: true, maxLen: 15),
                    if (!_pickup)
                      _field(_address, 'آدرس دقیق محل دریافت',
                          Icons.location_on,
                          lines: 2, need: true, minLen: 10, maxLen: 500),
                    ListTile(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.grey.shade200)),
                      tileColor: Colors.white,
                      leading: const Icon(Icons.calendar_month,
                          color: QandTheme.red),
                      title: const Text('تاریخ دریافت'),
                      subtitle: Text(_jalali(_date)),
                      trailing: const Icon(Icons.edit),
                      onTap: _pickDate,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 6, right: 4),
                      child: Text(
                        '⏳ آماده‌سازی سبد حداقل $_lead روز زمان می‌برد.',
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _field(_note, 'توضیح اضافه (اختیاری)',
                        Icons.note_alt_outlined,
                        lines: 2, maxLen: 500),
                    _counter('تعداد نفرات', _persons,
                        (v) => setState(() => _persons = v),
                        min: 1, max: 200),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                          color: QandTheme.cream,
                          borderRadius: BorderRadius.circular(16)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('جمع اقلام: ${formatToman(_itemsTotal)}'),
                          Text(_pickup
                              ? 'تحویل حضوری: رایگان ✅'
                              : _fee == 0
                                  ? 'هزینه ارسال: رایگان ✅ (بالای ${formatToman(freeDeliveryThreshold)})'
                                  : 'هزینه ارسال: ${formatToman(_fee)}'),
                          const SizedBox(height: 4),
                          Text(
                            'مبلغ قابل پرداخت (تقریبی): ${formatToman(_grand)}\nمبلغ نهایی را مدیر اعلام می‌کند.',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton(
                      onPressed: _sending ? null : _submit,
                      child: _sending
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('ثبت سفارش سبد'),
                    ),
                  ]),
                ),
    );
  }

  Widget _itemCard(CartItem item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                  child: Text(item.title,
                      style: const TextStyle(fontWeight: FontWeight.bold))),
              IconButton(
                tooltip: 'حذف از سبد',
                onPressed: () async {
                  await CartService().remove(widget.username, item.uid);
                  await _load();
                },
                icon: const Icon(Icons.delete_outline, color: Colors.red),
              ),
            ],
          ),
          if (item.options.isNotEmpty)
            Text(item.options,
                style: const TextStyle(fontSize: 12, color: Colors.black54)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(formatToman(item.total),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: QandTheme.red)),
              Row(children: [
                IconButton(
                  onPressed: item.qty > 1
                      ? () async {
                          await CartService()
                              .setQty(widget.username, item.uid, item.qty - 1);
                          await _load();
                        }
                      : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text('${item.qty}',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                IconButton(
                  onPressed: item.qty < 99
                      ? () async {
                          await CartService()
                              .setQty(widget.username, item.uid, item.qty + 1);
                          await _load();
                        }
                      : null,
                  icon: const Icon(Icons.add_circle, color: QandTheme.red),
                ),
              ]),
            ],
          ),
        ]),
      ),
    );
  }

  Widget _fulfillmentCard() {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('نحوه تحویل', style: TextStyle(fontWeight: FontWeight.bold)),
            RadioGroup<bool>(
              groupValue: _pickup,
              onChanged: (v) => setState(() => _pickup = v ?? false),
              child: const Column(
                children: [
                  RadioListTile<bool>(
                    title: Text('ارسال با پیک 🛵'),
                    value: false,
                  ),
                  RadioListTile<bool>(
                    title: Text('تحویل حضوری 🏪 (رایگان)'),
                    value: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String h, IconData ic,
      {bool need = false,
      int lines = 1,
      TextInputType? kb,
      int minLen = 0,
      int maxLen = 500}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        maxLines: lines,
        keyboardType: kb,
        maxLength: maxLen,
        decoration:
            InputDecoration(labelText: h, prefixIcon: Icon(ic), counterText: ''),
        validator: need
            ? (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty) return 'این فیلد لازم است';
                if (t.length < minLen) return 'حداقل $minLen کاراکتر وارد کن';
                return null;
              }
            : null,
      ),
    );
  }

  Widget _counter(String t, int v, ValueChanged<int> on,
      {int min = 1, int max = 50}) {
    return Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child:
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(t, style: const TextStyle(fontWeight: FontWeight.bold)),
            Row(children: [
              IconButton(
                  onPressed: v > min ? () => on(v - 1) : null,
                  icon: const Icon(Icons.remove_circle_outline)),
              Text('$v',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(
                  onPressed: v < max ? () => on(v + 1) : null,
                  icon: const Icon(Icons.add_circle, color: QandTheme.red)),
            ]),
          ]),
        ));
  }
}
