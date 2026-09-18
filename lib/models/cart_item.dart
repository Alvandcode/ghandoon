import '../utils/format.dart';

/// یک قلم در سبد خرید (محصول آماده یا کیک سفارشی).
/// [uid] شناسه یکتای قلم (دو کیک با کانفیگ متفاوت دو قلم جدا هستند).
/// [leadDays] حداقل زمان آماده‌سازی این قلم؛ lead سبد = بیشترین آن‌ها.
class CartItem {
  final String uid;
  final String productId;
  final String title;
  final int unitPrice;
  final int qty;
  final String unit;
  final String options;
  final int leadDays;

  const CartItem({
    required this.uid,
    required this.productId,
    required this.title,
    required this.unitPrice,
    this.qty = 1,
    this.unit = 'عدد',
    this.options = '',
    this.leadDays = 1,
  });

  int get total => unitPrice * qty;

  CartItem copyWith({int? qty}) => CartItem(
        uid: uid,
        productId: productId,
        title: title,
        unitPrice: unitPrice,
        qty: qty ?? this.qty,
        unit: unit,
        options: options,
        leadDays: leadDays,
      );

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'productId': productId,
        'title': title,
        'unitPrice': unitPrice,
        'qty': qty,
        'unit': unit,
        'options': options,
        'leadDays': leadDays,
      };

  factory CartItem.fromJson(Map<String, dynamic> m) => CartItem(
        uid: '${m['uid'] ?? ''}',
        productId: '${m['productId'] ?? ''}',
        title: '${m['title'] ?? ''}',
        unitPrice: parseIntSafe(m['unitPrice'], 0),
        qty: parseIntSafe(m['qty'], 1).clamp(1, 99),
        unit: '${m['unit'] ?? 'عدد'}',
        options: '${m['options'] ?? ''}',
        leadDays: parseIntSafe(m['leadDays'], 1).clamp(1, 30),
      );

  /// شرح یک‌خطی برای فاکتور/خلاصه سفارش.
  String get summaryLine {
    final o = options.isEmpty ? '' : ' ($options)';
    return '$title × $qty$o';
  }
}
