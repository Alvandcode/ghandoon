import 'package:flutter/material.dart';
import '../theme/qand_theme.dart';
import '../services/cart_service.dart';
import '../utils/format.dart';
import '../utils/order_rules.dart';
import 'cart_screen.dart';

/// کیک‌ساز سفارشی: وزن / طعم / فیلینگ / متن روی کیک → افزودن به سبد.
class CustomCakeScreen extends StatefulWidget {
  final String username;
  const CustomCakeScreen({super.key, required this.username});
  @override
  State<CustomCakeScreen> createState() => _CustomCakeScreenState();
}

class _CustomCakeScreenState extends State<CustomCakeScreen> {
  double _weight = 2.0;
  String _flavor = customCakeFlavors.first;
  String _filling = customCakeFillings.first;
  final _text = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  int get _price => customCakePrice(_weight) ?? 0;

  String get _summary => customCakeOptionsSummary(
        weightKg: _weight,
        flavor: _flavor,
        filling: _filling,
        cakeText: _text.text,
      );

  Future<void> _addToCart() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await CartService().add(
        username: widget.username,
        productId: 'custom-cake',
        title: 'کیک تولد سفارشی',
        unitPrice: _price,
        unit: 'عدد',
        options: _summary,
        leadDays: 3,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('به سبد اضافه شد 🎂')));
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) => CartScreen(username: widget.username)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(90),
        child: Container(
          decoration: QandTheme.headerGradient(radius: 24),
          child: SafeArea(
              child: Row(children: [
            IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_forward, color: Colors.white)),
            const Text('کیک تولد سفارشی 🎂',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 17)),
          ])),
        ),
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('وزن کیک', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final w in customCakeWeights)
              ChoiceChip(
                label: Text('${w.toString().replaceAll('.0', '')} کیلو'),
                selected: _weight == w,
                onSelected: (_) => setState(() => _weight = w),
              ),
          ],
        ),
        const SizedBox(height: 16),
        const Text('طعم کیک', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final f in customCakeFlavors)
              ChoiceChip(
                label: Text(f),
                selected: _flavor == f,
                onSelected: (_) => setState(() => _flavor = f),
              ),
          ],
        ),
        const SizedBox(height: 16),
        const Text('فیلینگ', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final f in customCakeFillings)
              ChoiceChip(
                label: Text(f),
                selected: _filling == f,
                onSelected: (_) => setState(() => _filling = f),
              ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _text,
          maxLength: 40,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'متن روی کیک (اختیاری)',
            hintText: 'مثلاً: تولدت مبارک سارا',
            prefixIcon: Icon(Icons.edit),
            counterText: '',
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: QandTheme.cream, borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_summary, style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 6),
              Text('قیمت: ${formatToman(_price)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: QandTheme.red,
                      fontSize: 16)),
              const Text('⏳ آماده‌سازی حداقل ۳ روز',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ElevatedButton(
          onPressed: _busy ? null : _addToCart,
          child: _busy
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('افزودن به سبد 🛒'),
        ),
      ]),
    );
  }
}
