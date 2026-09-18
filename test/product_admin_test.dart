import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qand_app/services/product_repository.dart';
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

  group('ProductRepository — آفلاین', () {
    test('ساخت/ویرایش/تغییر وضعیت آفلاین null/false می‌دهد (نه کرش)', () async {
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
}
