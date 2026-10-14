import 'package:flutter/material.dart';
import '../models/app_texts.dart';
import '../models/cake_config.dart';
import '../services/cake_config_service.dart';
import '../services/cart_service.dart';
import '../theme/qand_theme.dart';
import '../utils/format.dart';
import '../widgets/gradient_app_bar.dart';
import '../widgets/safe_scaffold.dart';
import 'cart_screen.dart';

/// کیک‌ساز سفارشی کاملاً داینامیک: وزن / بخش‌ها / زیرشاخه‌ها را از
/// [CakeConfig] می‌خواند (مدیر در پنل می‌سازد/حذف می‌کند).
///
/// انتخاب‌ها با `Map<String, Set<String>>` نگه داشته می‌شوند:
/// کلید = id بخش، مقدار = id گزینه‌های تیک‌خورده. گزینه‌ای که زیرشاخه
/// دارد، تا وقتی تیک نخورده زیرشاخه‌اش نمایش داده نمی‌شود.
class CustomCakeScreen extends StatefulWidget {
  final String username;
  const CustomCakeScreen({super.key, required this.username});

  @override
  State<CustomCakeScreen> createState() => _CustomCakeScreenState();
}

class _CustomCakeScreenState extends State<CustomCakeScreen> {
  CakeConfig? _config;
  double? _weight;
  final Map<String, Set<String>> _sel = {};
  final _text = TextEditingController();
  bool _busy = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final cfg = await CakeConfigService().load();
    if (!mounted) return;
    setState(() {
      _config = cfg;
      _weight = cfg.weights.isNotEmpty ? cfg.weights.first : null;
      _loading = false;
    });
  }

  Set<String> _picked(String sectionId) =>
      _sel[sectionId] ??= <String>{};

  void _toggle(CakeSection section, String optionId, {required bool on}) {
    setState(() {
      final set = _picked(section.id);
      if (section.isMulti) {
        if (on) {
          set.add(optionId);
        } else {
          set.remove(optionId);
        }
      } else {
        if (on) {
          set
            ..clear()
            ..add(optionId);
        } else {
          set.clear();
        }
      }
    });
  }

  /// گزینه‌ای که زیرشاخه دارد، فقط وقتی تیک خورده باز می‌شود.
  bool _optionActive(CakeOption option, CakeSection section) =>
      _picked(section.id).contains(option.id);

  int get _price {
    final cfg = _config;
    final w = _weight;
    if (cfg == null || w == null) return 0;
    return cfg.priceFor(w) ?? 0;
  }

  /// خلاصه انتخاب‌ها برای فاکتور/سبد: «بخش: گزینه، گزینه | ...»
  String summary(AppTexts T) {
    final cfg = _config;
    if (cfg == null) return '';
    final parts = <String>[];

    void walk(CakeSection section, {bool showTitle = true}) {
      final picked = _picked(section.id);
      // زیربخش‌ها همیشه (اگر گزینه‌ای تیک خورده باشد) نمایش داده می‌شوند
      if (picked.isNotEmpty && showTitle) {
        final labels = [
          for (final o in section.options)
            if (picked.contains(o.id)) o.label,
        ];
        if (labels.isNotEmpty) parts.add('${section.title}: ${labels.join('، ')}');
      }
      // زیرشاخه‌های گزینه‌های انتخاب‌شده
      for (final o in section.options) {
        if (picked.contains(o.id)) {
          for (final c in o.children) {
            walk(c);
          }
        }
      }
      // زیربخش‌های مستقیم بخش (مثل خامه/میوه/مغزیجات)
      for (final sub in section.subsections) {
        walk(sub);
      }
    }

    for (final s in cfg.sections) {
      walk(s);
    }

    final w = _weight;
    final weightText = w == null
        ? ''
        : '${T.t('cake.summary_prefix')} ${_num(w)} ${T.t('cake.weight_unit')}';
    final head = [weightText, if (parts.isNotEmpty) parts.join(' | ')]
        .where((e) => e.isNotEmpty)
        .join(' | ');
    final t = _text.text.trim();
    return t.isEmpty ? head : '$head | ${T.t('cake.summary_text_label')} $t';
  }

  String _num(double v) => v.toString().replaceAll('.0', '');

  Future<void> _addToCart(AppTexts T) async {
    final cfg = _config;
    if (_busy || cfg == null || _weight == null) return;
    setState(() => _busy = true);
    try {
      await CartService().add(
        username: widget.username,
        productId: 'custom-cake',
        title: T.t('cake.cart_item_title'),
        unitPrice: _price,
        unit: 'عدد',
        options: summary(T),
        leadDays: cfg.leadDays,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(T.t('cake.added_snackbar'))));
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => CartScreen(username: widget.username)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final T = AppTexts.of(context);
    final cfg = _config;
    return Scaffold(
      appBar: GradientAppBar.of(context, title: T.t('cake.title')),
      body: _loading || cfg == null
          ? const Center(child: CircularProgressIndicator())
          : Builder(builder: (ctx) => ListView(
                padding: bottomSafePadding(ctx),
                children: [
                  if (cfg.weights.isNotEmpty) ...[
                    Text(T.t('cake.weight_title'),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final w in cfg.weights)
                          ChoiceChip(
                            label: Text(
                                '${_num(w)} ${T.t('cake.weight_unit')}'),
                            selected: _weight == w,
                            selectedColor: QandTheme.red,
                            backgroundColor: Colors.white,
                            checkmarkColor: Colors.white,
                            labelStyle: TextStyle(
                                color: _weight == w
                                    ? Colors.white
                                    : QandTheme.ink),
                            onSelected: (_) =>
                                setState(() => _weight = w),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  // بخش‌های داینامیک
                  for (final s in cfg.sections) _buildSection(ctx, s, T),
                  const SizedBox(height: 4),
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
                        Text(summary(T),
                            style: const TextStyle(fontSize: 13)),
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

  /// یک بخش + زیربخش‌هایش را می‌سازد.
  Widget _buildSection(BuildContext ctx, CakeSection s, AppTexts T) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (s.title.trim().isNotEmpty) ...[
          Text(s.title,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
        ],
        // گزینه‌ها (اگر دارد)
        if (s.options.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final o in s.options) _buildOption(ctx, s, o, T),
            ],
          ),
        // زیرشاخه‌های مستقیم بخش (مثل خامه/میوه/مغزیجات)
        for (final sub in s.subsections) ...[
          const SizedBox(height: 12),
          _buildSection(ctx, sub, T),
        ],
      ],
    );
  }

  /// یک گزینه (چیپ) + زیرشاخه‌هایش اگر انتخاب شده.
  Widget _buildOption(
      BuildContext ctx, CakeSection s, CakeOption o, AppTexts T) {
    final active = _optionActive(o, s);
    final chip = s.isMulti
        ? FilterChip(
            label: Text(o.label),
            selected: active,
            selectedColor: QandTheme.red,
            backgroundColor: Colors.white,
            checkmarkColor: Colors.white,
            labelStyle: TextStyle(
                color: active ? Colors.white : QandTheme.ink),
            onSelected: (v) => _toggle(s, o.id, on: v),
          )
        : ChoiceChip(
            label: Text(o.label),
            selected: active,
            selectedColor: QandTheme.red,
            backgroundColor: Colors.white,
            checkmarkColor: Colors.white,
            labelStyle: TextStyle(
                color: active ? Colors.white : QandTheme.ink),
            onSelected: (v) => _toggle(s, o.id, on: v),
          );

    if (o.children.isEmpty) return chip;

    // گزینه شرطی: زیرشاخه‌ها فقط وقتی این گزینه تیک خورده
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        chip,
        if (active)
          Padding(
            padding: const EdgeInsets.only(right: 8, top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final c in o.children) _buildSection(ctx, c, T),
              ],
            ),
          ),
      ],
    );
  }
}