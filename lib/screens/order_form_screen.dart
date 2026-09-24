import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../theme/qand_theme.dart';
import '../models/product.dart';
import '../models/order.dart';
import '../services/order_service.dart';
import '../utils/format.dart';
import '../utils/order_rules.dart';
import '../widgets/gradient_app_bar.dart';
import '../widgets/safe_scaffold.dart';
import 'track_order_screen.dart';

class OrderFormScreen extends StatefulWidget {
  final Product product;
  final String username;
  const OrderFormScreen({super.key, required this.product, required this.username});
  @override
  State<OrderFormScreen> createState() => _OrderFormScreenState();
}

class _OrderFormScreenState extends State<OrderFormScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _note = TextEditingController();
  int _qty = 1;
  int _persons = 4;
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    // تاریخ پیش‌فرض = حداقل زمان آماده‌سازی همان محصول (کیک تولد ۳ روز و...)
    _date = minOrderDate(
      productId: widget.product.id,
      category: widget.product.category,
    );
  }

  @override
  void dispose() {
    _name.dispose(); _phone.dispose(); _address.dispose(); _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    // حداقل lead همان محصول؛ قبلاً همه «از امروز» بودند و کیک تولدِ امروز هم قبول می‌شد.
    final minDate = minOrderDate(
      productId: widget.product.id,
      category: widget.product.category,
    );
    final d = await showDatePicker(
      context: context,
      initialDate: _date.isBefore(minDate) ? minDate : _date,
      firstDate: minDate,
      lastDate: DateTime(minDate.year, minDate.month, minDate.day)
          .add(const Duration(days: 90)),
    );
    if (d != null) setState(() => _date = d);
  }

  /// تاریخ شمسی به فرمت 1405/06/20
  String _jalali(DateTime d) {
    final j = Jalali.fromDateTime(d);
    return '${j.year}/${j.month.toString().padLeft(2, '0')}/${j.day.toString().padLeft(2, '0')}';
  }

  Future<void> _submit() async {
    if (!_formKeyValid()) return;
    final order = QandOrder(
      // شناسه یکتا: میلی‌ثانیه + عدد تصادفی تا دو سفارش هم‌زمان هم تداخل نکنند.
      // قبلا فقط millisecondsSinceEpoch بود و در ثبت سریع پشت‌سرهم احتمال تصادم داشت.
      id: '${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(1 << 32)}',
      productId: widget.product.id,
      productTitle: widget.product.title,
      qty: _qty,
      persons: _persons,
      fullName: _name.text.trim(),
      phone: normalizeDigits(_phone.text.trim()),
      address: _address.text.trim(),
      deliveryDate: _jalali(_date),
      note: _note.text.trim(),
      status: OrderStatuses.pending,
      totalPrice: widget.product.price * _qty,
      createdAt: DateTime.now().toIso8601String(),
      owner: widget.username,
      trackingCode: generateTrackingCode(),
    );
    final saved = await OrderService().add(order);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('سفارشت ثبت شد 🌸 کد پیگیری: ${saved.displayCode}')));
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => TrackOrderScreen(username: widget.username)));
  }

  bool _formKeyValid() {
    if (!_form.currentState!.validate()) return false;
    if (!isValidIranMobile(_phone.text)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('شماره تماس باید مثل 09130000000 باشد (ارقام فارسی هم قبول است)')));
      return false;
    }
    // تاریخ باید حداقل lead همان محصول را رعایت کند (نه فقط «نه در گذشته»).
    if (!isOrderDateAllowed(
      picked: _date,
      productId: widget.product.id,
      category: widget.product.category,
    )) {
      final lead = minLeadDaysForProduct(
        productId: widget.product.id,
        category: widget.product.category,
      );
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'این محصول حداقل $lead روز زمان آماده‌سازی می‌خواهد؛ تاریخ دیگری انتخاب کن 🙏')));
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GradientAppBar.of(context, title: 'سفارش ${widget.product.title}'),
      body: Form(
        key: _form,
        child: ListView(padding: bottomSafePadding(context), children: [
          _counter('تعداد سفارش', _qty, (v) => setState(() => _qty = v)),
          _counter('تعداد نفرات', _persons, (v) => setState(() => _persons = v), min: 1, max: 200),
          _field(_name, 'نام و نام خانوادگی', Icons.person, need: true, minLen: 3, maxLen: 80),
          _field(_phone, 'شماره تماس (09...)', Icons.phone, kb: TextInputType.phone, need: true, maxLen: 15),
          // آدرس دقیق باید واقعا دقیق باشد؛ حداقل ۱۰ کاراکتر تا «تهران» خالی قبول نشود
          _field(_address, 'آدرس دقیق محل دریافت', Icons.location_on, lines: 2, need: true, minLen: 10, maxLen: 500),
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
            tileColor: Colors.white,
            leading: const Icon(Icons.calendar_month, color: QandTheme.red),
            title: const Text('تاریخ دریافت سفارش'),
            subtitle: Text(_jalali(_date)),
            trailing: const Icon(Icons.edit),
            onTap: _pickDate,
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 4),
            child: Text(
              '⏳ آماده‌سازی این محصول حداقل ${minLeadDaysForProduct(productId: widget.product.id, category: widget.product.category)} روز زمان می‌برد.',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 12),
          _field(_note, 'توضیح اضافه (اختیاری)', Icons.note_alt_outlined, lines: 2, maxLen: 500),
          const SizedBox(height: 12),
          Container(padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: QandTheme.cream, borderRadius: BorderRadius.circular(16)),
            child: Text('مبلغ تقریبی: ${formatToman(widget.product.price * _qty)}\nمبلغ نهایی را مدیر اعلام می‌کند.',
              style: const TextStyle(fontWeight: FontWeight.bold))),
          const SizedBox(height: 14),
          ElevatedButton(onPressed: _submit, child: const Text('ارسال سفارش')),
        ]),
      ),
    );
  }

  Widget _field(TextEditingController c, String h, IconData ic, {bool need = false, int lines = 1, TextInputType? kb, int minLen = 0, int maxLen = 500}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c, maxLines: lines, keyboardType: kb, maxLength: maxLen,
        decoration: InputDecoration(labelText: h, prefixIcon: Icon(ic), counterText: ''),
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

  Widget _counter(String t, int v, ValueChanged<int> on, {int min = 1, int max = 50}) {
    return Card(margin: const EdgeInsets.only(bottom: 12), child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(t, style: const TextStyle(fontWeight: FontWeight.bold)),
        Row(children: [
          IconButton(onPressed: v > min ? () => on(v - 1) : null, icon: const Icon(Icons.remove_circle_outline)),
          Text('$v', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          IconButton(onPressed: v < max ? () => on(v + 1) : null, icon: const Icon(Icons.add_circle, color: QandTheme.red)),
        ]),
      ]),
    ));
  }
}
