import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qand_app/models/cart_item.dart';
import 'package:qand_app/models/order.dart';
import 'package:qand_app/services/cart_service.dart';
import 'package:qand_app/services/notification_service.dart';
import 'package:qand_app/services/order_service.dart';
import 'package:qand_app/utils/order_rules.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CartService — سبد چندمحصولی', () {
    test('افزودن/تعداد/جمع', () async {
      SharedPreferences.setMockInitialValues({});
      final svc = CartService();
      await svc.add(
          username: 'ali', productId: 'p1', title: 'کیک', unitPrice: 100000);
      await svc.add(
          username: 'ali',
          productId: 'p2',
          title: 'کوکی',
          unitPrice: 50000,
          qty: 2);
      expect(await svc.count('ali'), 2);
      expect(await svc.total('ali'), 200000);
    });

    test('تغییر تعداد و حذف', () async {
      SharedPreferences.setMockInitialValues({});
      final svc = CartService();
      final item = await svc.add(
          username: 'ali', productId: 'p1', title: 'کیک', unitPrice: 100000);
      expect(await svc.setQty('ali', item.uid, 3), isTrue);
      expect(await svc.total('ali'), 300000);
      expect(await svc.setQty('ali', item.uid, 0), isTrue); // حذف
      expect(await svc.count('ali'), 0);
      expect(await svc.setQty('ali', 'nope', 2), isFalse);
    });

    test('سبد هر کاربر جداست + رکورد خراب نادیده', () async {
      SharedPreferences.setMockInitialValues({
        'qand_cart_ali': ['not-json{{{'],
      });
      final svc = CartService();
      await svc.add(
          username: 'reza', productId: 'p1', title: 'کیک', unitPrice: 10);
      expect(await svc.count('ali'), 0);
      expect(await svc.count('reza'), 1);
      await svc.clear('reza');
      expect(await svc.count('reza'), 0);
    });

    test('CartItem.fromJson مقادیر خراب را نرمال می‌کند', () {
      final i = CartItem.fromJson(
          {'uid': 'u', 'title': 't', 'qty': 500, 'unitPrice': '۴۵۰٬۰۰۰'});
      expect(i.qty, 99);
      expect(i.unitPrice, 450000);
      expect(i.summaryLine, contains('t × 99'));
    });
  });

  group('order_rules — کیک‌ساز و پیک', () {
    test('قیمت کیک سفارشی', () {
      expect(customCakePrice(2.0), 760000);
      expect(customCakePrice(1.5), 570000);
      expect(customCakePrice(2.5), isNull); // وزن نامعتبر
    });

    test('خلاصه کیک شامل وزن/طعم/فیلینگ/متن', () {
      final s = customCakeOptionsSummary(
        weightKg: 2.0,
        flavor: 'شکلاتی',
        filling: 'نوتلا',
        cakeText: 'تولدت مبارک',
      );
      expect(s, contains('2 کیلویی'));
      expect(s, contains('شکلاتی'));
      expect(s, contains('نوتلا'));
      expect(s, contains('تولدت مبارک'));
      final plain = customCakeOptionsSummary(
          weightKg: 1.0, flavor: 'وانیلی', filling: 'خامه وانیلی');
      expect(plain.contains('متن:'), isFalse);
    });

    test('هزینه پیک: حضوری ۰، بالای آستانه رایگان', () {
      expect(deliveryFee(pickup: true, itemsTotal: 100), 0);
      expect(deliveryFee(pickup: false, itemsTotal: 100), baseDeliveryFee);
      expect(
          deliveryFee(pickup: false, itemsTotal: freeDeliveryThreshold), 0);
      expect(deliveryFee(pickup: false, itemsTotal: 5000000), 0);
    });

    test('lead سبد = بیشترین + تاریخ مجاز', () {
      expect(cartLeadDays([1, 3, 2]), 3);
      expect(cartLeadDays([]), 1);
      expect(minCartDate(leadDays: 3, today: DateTime(2026, 9, 18)),
          DateTime(2026, 9, 21));
    });

    test('Fulfillment.fa', () {
      expect(Fulfillment.fa(Fulfillment.pickup), 'حضوری');
      expect(Fulfillment.fa(Fulfillment.delivery), 'ارسال با پیک');
    });
  });

  group('OrderChangeDetector — اعلان‌ها', () {
    QandOrder make(String id, String status) => QandOrder(
          id: id,
          productId: 'p1',
          productTitle: 'کیک',
          qty: 1,
          persons: 2,
          fullName: 'ت',
          phone: '09130000000',
          address: 'آدرس دقیق',
          deliveryDate: '1405/01/01',
          note: '',
          status: status,
          totalPrice: 100,
          createdAt: 'x',
          owner: 'ali',
        );

    test('سفارش جدید پیدا می‌شود', () {
      final oldL = [make('a', OrderStatuses.pending)];
      final newL = [
        make('a', OrderStatuses.pending),
        make('b', OrderStatuses.pending)
      ];
      expect(OrderChangeDetector.newOrderIds(oldList: oldL, newList: newL),
          ['b']);
      expect(
          OrderChangeDetector.newOrderIds(oldList: oldL, newList: oldL),
          isEmpty);
    });

    test('تغییر وضعیت (لیست و نقشه)', () {
      final oldL = [make('a', OrderStatuses.pending)];
      final newL = [make('a', OrderStatuses.approved)];
      expect(
          OrderChangeDetector.statusChanged(oldList: oldL, newList: newL)
              .map((e) => e.id),
          ['a']);
      expect(
          OrderChangeDetector.statusChangedFromMap(
              oldStatus: {'a': OrderStatuses.pending}, newList: newL).length,
          1);
      expect(
          OrderChangeDetector.statusChangedFromMap(
              oldStatus: {'a': OrderStatuses.approved},
              newList: newL),
          isEmpty);
    });
  });

  group('QandOrder — فیلدهای سبد/پیک roundtrip', () {
    test('add/byId فیلدهای جدید را نگه می‌دارد (آفلاین)', () async {
      SharedPreferences.setMockInitialValues({});
      final svc = OrderService();
      const o = QandOrder(
        id: 'cart-1',
        productId: 'cart',
        productTitle: 'سبد خرید (2 قلم)',
        qty: 3,
        persons: 4,
        fullName: 'تست',
        phone: '09130000000',
        address: 'تحویل حضوری',
        deliveryDate: '1405/01/01',
        note: '',
        status: OrderStatuses.pending,
        totalPrice: 500000,
        createdAt: 'x',
        owner: 'ali',
        trackingCode: 'QND-TEST01',
        fulfillment: Fulfillment.pickup,
        deliveryFee: 0,
        itemsSummary: 'کیک × 2 + کوکی × 1',
        cakeOptions: 'کیک 2کیلویی شکلاتی',
      );
      await svc.add(o);
      final fresh = await svc.byId('cart-1');
      expect(fresh!.fulfillment, Fulfillment.pickup);
      expect(fresh.isPickup, isTrue);
      expect(fresh.deliveryFee, 0);
      expect(fresh.itemsSummary, contains('کوکی'));
      expect(fresh.cakeOptions, contains('شکلاتی'));
      expect(fresh.displayItems, contains('کوکی'));
    });

    test('مپر ستون‌های جدید را می‌خواند/می‌نویسد', () {
      final o = QandOrderMapper.fromMap({
        'id': 'r1',
        'fulfillment': 'pickup',
        'delivery_fee': 0,
        'items_summary': 'کیک × 1',
        'cake_options': '',
      });
      expect(o.isPickup, isTrue);
      final m = QandOrderMapper.toMap(o);
      expect(m['fulfillment'], 'pickup');
      expect(m['items_summary'], 'کیک × 1');
    });
  });
}
