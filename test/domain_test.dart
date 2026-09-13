import 'package:flutter_test/flutter_test.dart';
import 'package:qand_app/models/order.dart';
import 'package:qand_app/models/product.dart';
import 'package:qand_app/services/auth_service.dart';

void main() {
  group('OrderStatuses', () {
    test('ترجمه فارسی همه وضعیت‌ها', () {
      expect(OrderStatuses.fa(OrderStatuses.pending), contains('مدیر'));
      expect(OrderStatuses.fa(OrderStatuses.awaitingPayment), 'در انتظار پرداخت');
      expect(OrderStatuses.fa(OrderStatuses.receiptSent), contains('فیش'));
      expect(OrderStatuses.fa(OrderStatuses.approved), 'تایید شد');
      expect(OrderStatuses.fa(OrderStatuses.ready), 'آماده تحویل');
      expect(OrderStatuses.fa(OrderStatuses.delivered), 'تحویل شد');
      expect(OrderStatuses.fa(OrderStatuses.cancelled), 'لغو شد');
    });

    test('وضعیت ناشناس همان رشته برمی‌گردد (بدون کرش)', () {
      expect(OrderStatuses.fa('weird_status'), 'weird_status');
    });

    test('flow ترتیب منطقی دارد', () {
      expect(OrderStatuses.flow.first, OrderStatuses.pending);
      expect(OrderStatuses.flow.last, OrderStatuses.delivered);
      expect(OrderStatuses.flow, isNot(contains(OrderStatuses.cancelled)));
    });
  });

  group('QandOrder', () {
    QandOrder make() => const QandOrder(
          id: '1',
          productId: 'p1',
          productTitle: 'کیک',
          qty: 2,
          persons: 4,
          fullName: 'تست',
          phone: '09130000000',
          address: 'آدرس',
          deliveryDate: '1405/06/20',
          note: '',
          status: OrderStatuses.pending,
          totalPrice: 1000,
          createdAt: 'x',
          owner: 'ali',
        );

    test('copyWith owner را نگه می‌دارد', () {
      final o = make().copyWith(status: OrderStatuses.approved, totalPrice: 2000);
      expect(o.owner, 'ali');
      expect(o.status, OrderStatuses.approved);
      expect(o.totalPrice, 2000);
      expect(o.qty, 2); // بقیه دست‌نخورده
    });

    test('owner پیش‌فرض خالی است (سازگاری با داده قدیمی)', () {
      const o = QandOrder(
        id: '1',
        productId: 'p1',
        productTitle: 'کیک',
        qty: 1,
        persons: 1,
        fullName: 'تست',
        phone: '09130000000',
        address: 'آدرس',
        deliveryDate: '1405/06/20',
        note: '',
        status: OrderStatuses.pending,
        totalPrice: 0,
        createdAt: 'x',
      );
      expect(o.owner, '');
    });
  });

  group('Product.fromMap', () {
    test('مقادیر رشته‌ای/عددی خراب کرش نمی‌کند', () {
      final p = Product.fromMap({'id': 5, 'price': '۴۵۰٬۰۰۰', 'category': 'کوکی'});
      expect(p.id, '5');
      expect(p.price, 450000);
      expect(p.asset, 'assets/images/cookies.png');
    });

    test('دسته ناشناس به cake_slice می‌افتد (فایل موجود)', () {
      final p = Product.fromMap({'id': 'x', 'category': 'نامشخص'});
      expect(p.asset, 'assets/images/cake_slice.png');
    });

    test('نگاشت هر دسته به فایل موجود', () {
      expect(Product.fromMap({'category': 'کیک خونگی'}).asset, 'assets/images/cupcake.png');
      expect(Product.fromMap({'category': 'کوکی'}).asset, 'assets/images/cookies.png');
      expect(Product.fromMap({'category': 'بیسکوییت'}).asset, 'assets/images/roll.png');
      expect(Product.fromMap({'category': 'کیک تولد'}).asset, 'assets/images/birthday.png');
    });
  });

  group('AuthService.hashPassword', () {
    test('قطعی و متفاوت برای کاربرهای مختلف', () {
      final a1 = AuthService.hashPassword('ali', '1234');
      final a2 = AuthService.hashPassword('ali', '1234');
      final b = AuthService.hashPassword('reza', '1234');
      final c = AuthService.hashPassword('ali', '5678');
      expect(a1, a2);
      expect(a1, isNot(b));
      expect(a1, isNot(c));
      expect(a1.startsWith('v1\$'), isTrue);
    });

    test('هش، خود رمز نیست (ذخیره plaintext لو نمی‌رود)', () {
      final h = AuthService.hashPassword('admin', '1234');
      expect(h.contains('1234'), isFalse);
    });
  });
}
