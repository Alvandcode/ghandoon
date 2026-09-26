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
              title: 'کیک شکلاتی', priceText: '450000', category: 'کیک'),
          isNull);
    });

    test('ارقام فارسی قیمت هم قبول است', () {
      expect(
          validateProductFields(
              title: 'شیرینی دانمارکی',
              priceText: '۴۵۰٬۰۰۰',
              category: 'شیرینی'),
          isNull);
    });

    test('اسم کوتاه رد می‌شود', () {
      expect(
          validateProductFields(
              title: 'ک', priceText: '450000', category: 'کیک'),
          isNotNull);
      expect(
          validateProductFields(
              title: '  ', priceText: '450000', category: 'کیک'),
          isNotNull);
    });

    test('قیمت نامعتبر رد می‌شود', () {
      expect(
          validateProductFields(
              title: 'شیرینی', priceText: 'abc', category: 'شیرینی'),
          isNotNull);
      expect(
          validateProductFields(
              title: 'شیرینی', priceText: '0', category: 'شیرینی'),
          isNotNull);
      expect(
          validateProductFields(
              title: 'شیرینی', priceText: '', category: 'شیرینی'),
          isNotNull);
    });

    test('دسته نامعتبر رد می‌شود', () {
      expect(
          validateProductFields(
              title: 'شیرینی', priceText: '450000', category: 'پیتزا'),
          isNotNull);
      expect(
          validateProductFields(
              title: 'شیرینی', priceText: '450000', category: ''),
          isNotNull);
      expect(
          validateProductFields(
              title: 'شیرینی', priceText: '450000', category: 'کوکی'),
          isNotNull);
    });

    test('allowedCategories سفارشی قبول می‌شود', () {
      expect(
          validateProductFields(
              title: 'کیک',
              priceText: '450000',
              category: 'قهوه',
              allowedCategories: ['قهوه']),
          isNull);
      expect(
          validateProductFields(
              title: 'کیک',
              priceText: '450000',
              category: 'کیک',
              allowedCategories: ['قهوه']),
          isNotNull);
    });
  });

  group('normalizeProductCategory', () {
    const mains = ['دسر', 'شیرینی', 'کیک', 'شکلات'];

    test('دسته اصلی همان‌طور می‌ماند', () {
      expect(normalizeProductCategory('کیک', mains), 'کیک');
      expect(normalizeProductCategory('  دسر  ', mains), 'دسر');
    });

    test('دسته قدیمی به شاخه اصلی نگاشت می‌شود', () {
      expect(normalizeProductCategory('کیک خونگی', mains), 'کیک');
      expect(normalizeProductCategory('کیک تولد', mains), 'کیک');
      expect(normalizeProductCategory('کوکی', mains), 'شیرینی');
      expect(normalizeProductCategory('بیسکوییت', mains), 'شیرینی');
    });

    test('نامعلوم دست‌نخورده برمی‌گردد', () {
      expect(normalizeProductCategory('پیتزا', mains), 'پیتزا');
      expect(normalizeProductCategory('', mains), '');
    });
  });

  group('ProductRepository — آفلاین', () {    test('ساخت/ویرایش/تغییر وضعیت آفلاین null/false می‌دهد (نه کرش)', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = ProductRepository();
      expect(
          await repo.createProduct(
              title: 'تست', category: 'کیک', price: 1000, unit: 'عدد'),
          isNull);
      expect(
          await repo.updateProduct('x',
              title: 'تست', category: 'کیک', price: 1000, unit: 'عدد'),
          isNull);
      expect(await repo.setActive('x', false), isFalse);
      expect(await repo.updatePrice('x', 1000), isFalse);
    });

    test('ورودی نامعتبر حتی بدون تماس با سرور رد می‌شود', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = ProductRepository();
      expect(
          await repo.createProduct(
              title: '', category: 'کیک', price: 1000, unit: 'عدد'),
          isNull);
      expect(await repo.updatePrice('x', -5), isFalse);
    });
  });

  group('describeWriteError — پیام فارسی علت شکست ذخیره', () {
    test('42501/RLS → دسترسی نوشتن بسته', () {
      expect(
          ProductRepository.describeWriteError(
              Exception('PostgrestException{code: 42501, message: permission}')),
          contains('دسترسی نوشتن بسته'));
      expect(
          ProductRepository.describeWriteError(
              Exception('new row violates row-level security policy')),
          contains('دسترسی نوشتن بسته'));
    });

    test('23505 unique → عنوان تکراری', () {
      expect(
          ProductRepository.describeWriteError(
              Exception('PostgrestException{code: 23505, message: duplicate}')),
          contains('قبلاً ثبت شده'));
    });

    test('23514 check constraint → اجرای schema.sql', () {
      expect(
          ProductRepository.describeWriteError(Exception(
              'new row for relation "products" violates check constraint "products_category_check"')),
          contains('schema.sql'));
    });

    test('42703 ستون ناقص → اجرای schema.sql', () {
      expect(
          ProductRepository.describeWriteError(
              Exception('column app_settings.main_categories does not exist')),
          contains('schema.sql'));
    });

    test('قطع شبکه → پیام اتصال', () {
      expect(ProductRepository.describeWriteError(Exception('SocketException: Failed host lookup')),
          contains('اتصال شبکه قطع'));
    });

    test('ناشناخته → خطای ناشناخته سرور', () {
      expect(ProductRepository.describeWriteError(Exception('boom')),
          contains('ناشناخته'));
    });
  });

  group('Product — عکس صفحه توضیحات', () {
    test('fromMap ستون detail_image_url را می‌خواند', () {
      final p = Product.fromMap({
        'id': '1',
        'category': 'کیک',
        'image_url': 'https://x/main.jpg',
        'detail_image_url': 'https://x/detail.jpg',
      });
      expect(p.imageUrl, 'https://x/main.jpg');
      expect(p.detailImageUrl, 'https://x/detail.jpg');
    });

    test('قدیمی بدون ستون جدید = null (نه کرش)', () {
      final p = Product.fromMap({'id': '1', 'category': 'کیک'});
      expect(p.detailImageUrl, isNull);
      expect(p.imageUrl, isNull);
    });

    test('copyWith عکس توضیحات را نگه می‌دارد/عوض می‌کند', () {
      final p = Product.fromMap({'id': '1', 'category': 'کیک'});
      expect(p.copyWith(price: 5).detailImageUrl, isNull);
      expect(p.copyWith(detailImageUrl: 'https://x/d.jpg').detailImageUrl,
          'https://x/d.jpg');
    });
  });

  group('SettingsService — دسته‌های اصلی', () {
    test('decode خراب → لیست خالی (نه کرش)', () {
      expect(SettingsService.decodeMainCategories(''), isEmpty);
      expect(SettingsService.decodeMainCategories('not-json'), isEmpty);
      expect(SettingsService.decodeMainCategories('{"a":1}'), isEmpty);
      expect(SettingsService.decodeMainCategories('["کیک","دسر"]'),
          ['کیک', 'دسر']);
    });

    test('sanitize همیشه دقیقاً ۴ مورد معتبر می‌دهد', () {
      expect(SettingsService.sanitizeMainCategories([]).length, 4);
      expect(SettingsService.sanitizeMainCategories(['', '  ', 'کیک']).length,
          4);
      final dups =
          SettingsService.sanitizeMainCategories(['کیک', 'کیک', 'دسر']);
      expect(dups.take(2), ['کیک', 'دسر']);
      expect(dups.length, 4);
      final tooMany = SettingsService.sanitizeMainCategories(
          ['الف', 'ب', 'پ', 'ت', 'ث']);
      expect(tooMany, ['الف', 'ب', 'پ', 'ت']);
    });

    test('save/load آفلاین روی SharedPreferences کار می‌کند', () async {
      SharedPreferences.setMockInitialValues({});
      final svc = SettingsService();
      final ok = await svc.saveMainCategories(['دسر', 'شیرینی', 'کیک', 'شکلات']);
      expect(ok, isFalse); // آفلاین
      final loaded = await svc.loadMainCategories();
      expect(loaded, ['دسر', 'شیرینی', 'کیک', 'شکلات']);
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
