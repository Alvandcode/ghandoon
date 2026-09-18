import 'package:flutter_test/flutter_test.dart';
import 'package:qand_app/utils/order_rules.dart';
import 'package:qand_app/models/product.dart';

void main() {
  group('order_rules — حداقل زمان آماده‌سازی', () {
    test('کیک تولد ۳ روز، خونگی ۲ روز، بقیه ۱ روز', () {
      expect(
          minLeadDaysForProduct(productId: 'birthday', category: 'کیک تولد'), 3);
      expect(
          minLeadDaysForProduct(productId: 'homemade', category: 'کیک خونگی'),
          2);
      expect(minLeadDaysForProduct(productId: 'cookie', category: 'کوکی'), 1);
      expect(
          minLeadDaysForProduct(productId: 'x', category: 'نامشخص'), 1);
    });

    test('minOrderDate امروز + lead (بدون ساعت)', () {
      final today = DateTime(2026, 9, 18, 23, 59);
      expect(
        minOrderDate(
            productId: 'birthday', category: 'کیک تولد', today: today),
        DateTime(2026, 9, 21),
      );
      expect(
        minOrderDate(productId: 'cookie', category: 'کوکی', today: today),
        DateTime(2026, 9, 19),
      );
    });

    test('isOrderDateAllowed مرزها', () {
      final today = DateTime(2026, 9, 18);
      expect(
        isOrderDateAllowed(
          picked: DateTime(2026, 9, 20),
          productId: 'birthday',
          category: 'کیک تولد',
          today: today,
        ),
        isFalse,
      );
      expect(
        isOrderDateAllowed(
          picked: DateTime(2026, 9, 21),
          productId: 'birthday',
          category: 'کیک تولد',
          today: today,
        ),
        isTrue,
      );
    });
  });

  group('Product — isActive', () {
    test('پیش‌فرض فعال، خواندن هر دو حالت سرور', () {
      expect(
        Product.fromMap({'id': '1', 'category': 'کوکی'}).isActive,
        isTrue,
      );
      expect(
        Product.fromMap(
            {'id': '1', 'category': 'کوکی', 'is_active': false}).isActive,
        isFalse,
      );
      expect(
        Product.fromMap(
            {'id': '1', 'category': 'کوکی', 'is_active': 0}).isActive,
        isFalse,
      );
    });

    test('copyWith قیمت/وضعیت را عوض می‌کند', () {
      final p = Product.fromMap({'id': '1', 'category': 'کوکی', 'price': 100});
      final q = p.copyWith(price: 200, isActive: false);
      expect(q.price, 200);
      expect(q.isActive, isFalse);
      expect(q.title, p.title);
    });
  });
}
