import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qand_app/models/order.dart';
import 'package:qand_app/services/order_service.dart';
import 'package:qand_app/services/settings_service.dart';

/// رگرسیون:
/// ۱. ویرایش کامل سفارش توسط مدیر (متن‌ها + اعداد).
/// ۲. عکس شاخه با نام ذخیره می‌شود (نه ایندکس) تا حذف یک شاخه
///    عکس بقیه را جابه‌جا نکند؛ حذف شاخه ورودی عکسش را هم می‌برد.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OrderService.updateDetails — ویرایش مدیر', () {
    QandOrder make(String id) => QandOrder(
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
          owner: 'ali',
        );

    test('ویرایش متن‌ها + اعداد موفق', () async {
      SharedPreferences.setMockInitialValues({});
      final svc = OrderService();
      await svc.add(make('e1'));
      final res = await svc.updateDetails('e1',
          fullName: 'رضا رضایی',
          phone: '09131112233',
          address: 'اصفهان، خیابان اصلی، پلاک ۱۰',
          deliveryDate: '1405/07/01',
          qty: 3,
          persons: 6,
          totalPrice: 750000,
          deliveryFee: 45000,
          fulfillment: 'delivery',
          note: 'کم‌شیرین');
      expect(res, OrderService.updateOk);
      final fresh = await svc.byId('e1');
      expect(fresh!.fullName, 'رضا رضایی');
      expect(fresh.qty, 3);
      expect(fresh.totalPrice, 750000);
      expect(fresh.note, 'کم‌شیرین');
    });

    test('نام کوتاه / موبایل بد / آدرس کوتاه رد می‌شود', () async {
      SharedPreferences.setMockInitialValues({});
      final svc = OrderService();
      await svc.add(make('e2'));
      expect(await svc.updateDetails('e2', fullName: 'ا'),
          OrderService.updateBadField);
      expect(await svc.updateDetails('e2', phone: '123'),
          OrderService.updateBadField);
      expect(await svc.updateDetails('e2', address: 'تهران'),
          OrderService.updateBadField);
      expect(await svc.updateDetails('e2', qty: 0),
          OrderService.updateBadField);
      expect(await svc.updateDetails('e2', totalPrice: -5),
          OrderService.updateBadPrice);
      expect(await svc.updateDetails('e2', fulfillment: 'drone'),
          OrderService.updateBadField);
      final fresh = await svc.byId('e2');
      expect(fresh!.fullName, 'تست');
    });

    test('سفارش ناموجود not_found', () async {
      SharedPreferences.setMockInitialValues({});
      expect(
          await OrderService().updateDetails('missing',
              fullName: 'رضا رضایی'),
          OrderService.updateNotFound);
    });
  });

  group('BranchImages — نگاشت نام‌محور', () {
    test('decode امن: خراب → خالی، خالی‌ها حذف', () {
      expect(SettingsService.decodeBranchImages(''), isEmpty);
      expect(SettingsService.decodeBranchImages('not-json'), isEmpty);
      final m = SettingsService.decodeBranchImages(
          '{"دسر":"https://x/a.jpg","شیرینی":"  ","":"https://x/b.jpg"}');
      expect(m, {'دسر': 'https://x/a.jpg'});
    });

    test('sanitize: فقط ورودی‌های پر', () {
      expect(
          SettingsService.sanitizeBranchImages(
              {'دسر': 'https://x/a.jpg', 'کیک': '  ', '': 'https://x/b.jpg'}),
          {'دسر': 'https://x/a.jpg'});
    });

    test('save/load لوکال (آفلاین) + حذف شاخه عکسش را می‌برد', () async {
      SharedPreferences.setMockInitialValues({});
      final svc = SettingsService();
      await svc.saveBranchImages({
        'دسر': 'https://x/desar.jpg',
        'شیرینی': 'https://x/shirini.jpg',
      });
      expect(await svc.loadBranchImages(),
          {'دسر': 'https://x/desar.jpg', 'شیرینی': 'https://x/shirini.jpg'});
      // شاخه حذف شد → با validTitles جدید ذخیره → عکسش هم رفت
      await svc.saveBranchImages(
          {'دسر': 'https://x/desar.jpg', 'شیرینی': 'https://x/shirini.jpg'},
          validTitles: ['دسر']);
      expect(await svc.loadBranchImages(), {'دسر': 'https://x/desar.jpg'});
    });
  });
}
