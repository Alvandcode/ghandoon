import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qand_app/models/product.dart';
import 'package:qand_app/services/product_repository.dart';
import 'package:qand_app/services/settings_service.dart';
import 'package:qand_app/utils/product_validate.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('validateProductFields', () {
    test('ورودی درست قبول است', () {
      expect(
          validateProductFields(
              title: 'کیک شکلاتی',
              priceText: '450000',
              category: 'کیک خونگی'),
          isNull);
    });

    test('ارقام فارسی قیمت هم قبول است', () {
      expect(
          validateProductFields(
              title: 'کوکی',
              priceText: '۴۵۰٬۰۰۰',
              category: 'کوکی'),
          isNull);
    });

    test('اسم کوتاه رد می‌شود', () {
      expect(
          validateProductFields(
              title: 'ک', priceText: '450000', category: 'کوکی'),
          isNotNull);
      expect(
          validateProductFields(
              title: '  ', priceText: '450000', category: 'کوکی'),
          isNotNull);
    });

    test('قیمت نامعتبر رد می‌شود', () {
      expect(
          validateProductFields(
              title: 'کوکی', priceText: 'abc', category: 'کوکی'),
          isNotNull);
      expect(
          validateProductFields(
              title: 'کوکی', priceText: '0', category: 'کوکی'),
          isNotNull);
      expect(
          validateProductFields(
              title: 'کوکی', priceText: '', category: 'کوکی'),
          isNotNull);
    });

    test('دسته نامعتبر رد می‌شود', () {
      expect(
          validateProductFields(
              title: 'کوکی', priceText: '450000', category: 'پیتزا'),
          isNotNull);
      expect(
          validateProductFields(
              title: 'کوکی', priceText: '450000', category: ''),
          isNotNull);
    });
  });

  group('ProductRepository — آفلاین', () {    test('ساخت/ویرایش/تغییر وضعیت آفلاین null/false می‌دهد (نه کرش)', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = ProductRepository();
      expect(
          await repo.createProduct(
              title: 'تست', category: 'کوکی', price: 1000, unit: 'عدد'),
          isNull);
      expect(
          await repo.updateProduct('x',
              title: 'تست', category: 'کوکی', price: 1000, unit: 'عدد'),
          isNull);
      expect(await repo.setActive('x', false), isFalse);
      expect(await repo.updatePrice('x', 1000), isFalse);
    });

    test('ورودی نامعتبر حتی بدون تماس با سرور رد می‌شود', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = ProductRepository();
      expect(
          await repo.createProduct(
              title: '', category: 'کوکی', price: 1000, unit: 'عدد'),
          isNull);
      expect(await repo.updatePrice('x', -5), isFalse);
    });
  });

  group('Product — عکس صفحه توضیحات', () {
    test('fromMap ستون detail_image_url را می‌خواند', () {
      final p = Product.fromMap({
        'id': '1',
        'category': 'کوکی',
        'image_url': 'https://x/main.jpg',
        'detail_image_url': 'https://x/detail.jpg',
      });
      expect(p.imageUrl, 'https://x/main.jpg');
      expect(p.detailImageUrl, 'https://x/detail.jpg');
    });

    test('قدیمی بدون ستون جدید = null (نه کرش)', () {
      final p = Product.fromMap({'id': '1', 'category': 'کوکی'});
      expect(p.detailImageUrl, isNull);
      expect(p.imageUrl, isNull);
    });

    test('copyWith عکس توضیحات را نگه می‌دارد/عوض می‌کند', () {
      final p = Product.fromMap({'id': '1', 'category': 'کوکی'});
      expect(p.copyWith(price: 5).detailImageUrl, isNull);
      expect(p.copyWith(detailImageUrl: 'https://x/d.jpg').detailImageUrl,
          'https://x/d.jpg');
    });
  });

  group('SettingsService.save', () {
    test('آفلاین: فقط آینه لوکال + false (نه کرش)', () async {
      SharedPreferences.setMockInitialValues({});
      final ok = await SettingsService().save(
          card: '6037991112345678', owner: 'قندون', zarin: '');
      expect(ok, isFalse);
      final loaded = await SettingsService().load();
      expect(loaded['card'], '6037991112345678');
      expect(loaded['owner'], 'قندون');
    });
  });
}
