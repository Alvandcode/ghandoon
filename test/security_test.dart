import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qand_app/models/order.dart';
import 'package:qand_app/services/auth_service.dart';
import 'package:qand_app/services/order_service.dart';
import 'package:qand_app/utils/format.dart';

/// تست‌های امنیتی و رگرسیون برای ایرادهای رفع‌شده.
/// همه باید بدون سوپابیس (حالت آفلاین CI) سبز باشند.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Auth — رمز trim نمی‌شود + admin رزرو', () {
    test('هش رمز با فاصله با بدون فاصله فرق دارد (فاصله جزئی از رمز است)', () {
      final withSpaces = AuthService.hashPassword('ali', ' 1234 ');
      final plain = AuthService.hashPassword('ali', '1234');
      expect(withSpaces, isNot(plain));
    });

    test('نام admin با حروف بزرگ هم رزرو است', () async {
      SharedPreferences.setMockInitialValues({});
      final s = AuthService();
      expect(await s.register('Admin', '123456'), isFalse);
      expect(await s.register('ADMIN', '123456'), isFalse);
      expect(await s.register('admin', '123456'), isFalse);
    });

    test('ثبت‌نام و لاگین عادی کار می‌کند', () async {
      SharedPreferences.setMockInitialValues({});
      final s = AuthService();
      expect(await s.register('ali_test', 'pass1234'), isTrue);
      expect(await s.login('ali_test', 'pass1234'), isTrue);
      expect(await s.currentUser(), 'ali_test');
      expect(await s.isAdmin(), isFalse);
    });

    test('لاگین با رمز اشتباه ناموفق است', () async {
      SharedPreferences.setMockInitialValues({});
      final s = AuthService();
      await s.register('reza_test', 'mypass');
      expect(await s.login('reza_test', 'wrong'), isFalse);
    });

    test('رمزِ با فاصله اضافی پذیرفته نمی‌شود (fallback trim حذف شد)', () async {
      SharedPreferences.setMockInitialValues({});
      final s = AuthService();
      await s.register(' spacing_test ', 'pass1234');
      expect(await s.login(' spacing_test', ' pass1234'), isFalse);
      expect(await s.login('spacing_test ', 'pass1234 '), isFalse);
      expect(await s.login('spacing_test', 'pass1234'), isTrue);
    });
  });

  group('OrderService — حریم خصوصی + اعتبارسنجی', () {
    QandOrder make(String id, String owner) => QandOrder(
          id: id,
          productId: 'p1',
          productTitle: 'کیک',
          qty: 1,
          persons: 2,
          fullName: 'تست',
          phone: '09130000000',
          address: 'آدرس دقیق تستی برای بررسی',
          deliveryDate: '1405/06/20',
          note: '',
          status: OrderStatuses.pending,
          totalPrice: 1000,
          createdAt: 'x',
          owner: owner,
        );

    test('کاربر عادی فقط سفارش خودش را می‌بیند (legacy بدون owner فقط مدیر)', () async {
      SharedPreferences.setMockInitialValues({});
      final svc = OrderService();
      await svc.add(make('id-ali-1', 'ali'));
      await svc.add(make('id-reza-1', 'reza'));
      await svc.add(make('id-legacy-1', ''));

      final ali = await svc.all(forUser: 'ali');
      expect(ali.map((e) => e.id), contains('id-ali-1'));
      expect(ali.map((e) => e.id), isNot(contains('id-reza-1')));
      // مهم: legacy بدون owner نباید به کاربر عادی نشت کند
      expect(ali.map((e) => e.id), isNot(contains('id-legacy-1')));

      final admin = await svc.all(isAdmin: true);
      expect(admin.length, 3);

      // all() بدون آرگومان دیگر همه را نمی‌دهد (جلوگیری از نشت تصادفی)
      expect(await svc.all(), isEmpty);
    });

    test('byId سفارش ناموجود null می‌دهد (نه کرش)', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await OrderService().byId('no-such-id'), isNull);
    });

    test('updateStatus وضعیت نامعتبر را قبول نمی‌کند', () async {
      SharedPreferences.setMockInitialValues({});
      final svc = OrderService();
      await svc.add(make('id-x', 'ali'));
      final res =
          await svc.updateStatus('id-x', 'weird_status_hacker');
      expect(res, OrderService.updateBadStatus);
      final fresh = await svc.byId('id-x');
      expect(fresh!.status, OrderStatuses.pending);
    });

    test('updateStatus مبلغ نامعتبر را قبول نمی‌کند', () async {
      SharedPreferences.setMockInitialValues({});
      final svc = OrderService();
      await svc.add(make('id-y', 'ali'));
      final res = await svc.updateStatus('id-y', OrderStatuses.awaitingPayment,
          totalPrice: -5);
      expect(res, OrderService.updateBadPrice);
      final fresh = await svc.byId('id-y');
      expect(fresh!.status, OrderStatuses.pending);
      expect(fresh.totalPrice, 1000);
    });

    test('updateStatus سفارش ناموجود را گزارش می‌کند', () async {
      SharedPreferences.setMockInitialValues({});
      final res = await OrderService().updateStatus(
          'no-such', OrderStatuses.approved);
      expect(res, OrderService.updateNotFound);
    });

    test('رکورد خراب کل لیست را کرش نمی‌کند', () async {
      SharedPreferences.setMockInitialValues({
        'qand_orders': ['not-json{{{', '{"id": 1}']
      });
      final list = await OrderService().all(isAdmin: true);
      // رکورد دوم decode می‌شود (با مقادیر پیش‌فرض)، اولی نادیده گرفته می‌شود
      expect(list.length, 1);
    });
  });

  group('Payment gating — منطق قفل پرداخت', () {
    bool canPay(String status) =>
        status != OrderStatuses.pending && status != OrderStatuses.cancelled;

    test('pending و cancelled قفل‌اند، بقیه باز', () {
      expect(canPay(OrderStatuses.pending), isFalse);
      expect(canPay(OrderStatuses.cancelled), isFalse);
      expect(canPay(OrderStatuses.awaitingPayment), isTrue);
      expect(canPay(OrderStatuses.receiptSent), isTrue);
      expect(canPay(OrderStatuses.approved), isTrue);
      expect(canPay(OrderStatuses.ready), isTrue);
      expect(canPay(OrderStatuses.delivered), isTrue);
    });
  });

  group('Format — لبه‌ها', () {
    test('موبایل با خط‌تیره نامعتبر است ولی فاصله داخل شماره قبول است', () {
      expect(isValidIranMobile('0913-000-0000'), isFalse);
      expect(isValidIranMobile('0913 000 0000'), isTrue);
      expect(normalizeDigits('0913 000 0000'), '09130000000');
    });

    test('parsePrice متن ترکیبی را قبول نمی‌کند', () {
      expect(parsePrice('450000 تومان'), isNull);
      expect(parsePrice('450-000'), isNull);
    });

    test('کپی کارت فقط ارقام (منطق PaymentScreen)', () {
      const stored = '6037-9911-1234-5678';
      final digits = stored.replaceAll(RegExp(r'[^0-9]'), '');
      expect(digits, '6037991112345678');
      expect(RegExp(r'^\d{16}$').hasMatch(digits), isTrue);
    });

    test('basename مسیر فایل لو نمی‌رود', () {
      String base(String path) {
        final p = path.replaceAll('\\', '/');
        final i = p.lastIndexOf('/');
        return i >= 0 ? p.substring(i + 1) : p;
      }

      expect(base('/data/user/0/com.qand.app/cache/abc.jpg'), 'abc.jpg');
      expect(base(r'C:\Users\a\img.png'), 'img.png');
    });
  });
}
