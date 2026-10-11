import 'package:flutter/material.dart';
import '../models/app_texts.dart';
import '../theme/qand_theme.dart';
import '../services/cart_service.dart';
import '../utils/format.dart';
import '../utils/order_rules.dart';
import '../widgets/gradient_app_bar.dart';
import '../widgets/safe_scaffold.dart';
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

  /// خلاصه سفارش با متن‌های مدیر (پیشوند/وسط/برچسب متن قابل تغییر است).
  String summaryFor(AppTexts T) {
    final w = _weight.toString().replaceAll('.0', '');
    final t = _text.text.trim();
    final base = '${T.t('cake.summary_prefix')} $w ${T.t('cake.weight_unit')} '
        '$_flavor ${T.t('cake.summary_middle')} $_filling';
    return t.isEmpty ? base : '$base | ${T.t('cake.summary_text_label')} $t';
  }

  Future<void> _addToCart(AppTexts T) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await CartService().add(
        username: widget.username,
        productId: 'custom-cake',
        title: T.t('cake.cart_item_title'),
        unitPrice: _price,
        unit: 'عدد',
        options: summaryFor(T),
        leadDays: 3,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(T.t('cake.added_snackbar'))));
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
    final T = AppTexts.of(context);
    return Scaffold(
      appBar: GradientAppBar.of(context, title: T.t('cake.title')),
      body: Builder(builder: (ctx) => ListView(
        padding: bottomSafePadding(ctx),
        children: [
          Text(T.t('cake.weight_title'),
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final w in customCakeWeights)
                ChoiceChip(
                  label: Text('${w.toString().replaceAll('.0', '')} '
                      '${T.t('cake.weight_unit')}'),
                  selected: _weight == w,
                  selectedColor: QandTheme.red,
                  backgroundColor: Colors.white,
                  checkmarkColor: Colors.white,
                  labelStyle: TextStyle(
                      color: _weight == w ? Colors.white : QandTheme.ink),
                  onSelected: (_) => setState(() => _weight = w),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(T.t('cake.flavor_title'),
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final f in customCakeFlavors)
                ChoiceChip(
                  label: Text(f),
                  selected: _flavor == f,
                  selectedColor: QandTheme.red,
                  backgroundColor: Colors.white,
                  checkmarkColor: Colors.white,
                  labelStyle: TextStyle(
                      color: _flavor == f ? Colors.white : QandTheme.ink),
                  onSelected: (_) => setState(() => _flavor = f),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(T.t('cake.filling_title'),
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final f in customCakeFillings)
                ChoiceChip(
                  label: Text(f),
                  selected: _filling == f,
                  selectedColor: QandTheme.red,
                  backgroundColor: Colors.white,
                  checkmarkColor: Colors.white,
                  labelStyle: TextStyle(
                      color: _filling == f ? Colors.white : QandTheme.ink),
                  onSelected: (_) => setState(() => _filling = f),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _text,
            maxLength: 40,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: T.t('cake.text_label'),
              hintText: T.t('cake.text_hint'),
              prefixIcon: const Icon(Icons.edit),
              counterText: '',
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: QandTheme.cream,
                borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(summaryFor(T), style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 6),
                Text('${T.t('cake.price_label')} ${formatToman(_price)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: QandTheme.red,
                        fontSize: 16)),
                Text(T.t('cake.lead_note'),
                    style: const TextStyle(
                        fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: _busy ? null : () => _addToCart(T),
            child: _busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Text(T.t('cake.add_button')),
          ),
        ],
      )),
    );
  }
}
