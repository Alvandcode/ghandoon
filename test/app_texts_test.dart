import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qand_app/models/app_texts.dart';
import 'package:qand_app/screens/custom_cake_screen.dart';
import 'package:qand_app/services/app_texts_service.dart';

/// رگرسیون متن‌های قابل‌ویرایش:
/// کلیدهای ناشناخته نباید ذخیره/بارگذاری شوند، خالی‌ها به پیش‌فرض
/// برگردند، و صفحه کیک‌ساز از متن‌های سفارشی استفاده کند.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppTexts — پیش‌فرض‌ها و required', () {
    test('همه کلیدها یکتا هستند', () {
      final keys = appTextEntries.map((e) => e.key).toList();
      expect(keys.toSet().length, keys.length);
    });

    test('هر کلید پیش‌فرض غیرخالی دارد', () {
      for (final e in appTextEntries) {
        expect(e.defaultValue.trim(), isNotEmpty, reason: e.key);
      }
    });

    test('ت: مقدار ذخیره‌شده برمی‌گردد، خالی → پیش‌فرض', () {
      final n = AppTextsNotifier();
      n.replaceAll({'home.headline': 'سلام کیک دوست ✨'});
      expect(n.t('home.headline'), 'سلام کیک دوست ✨');
      // کلید ذخیره‌نشده → پیش‌فرض
      expect(n.t('home.cart_tooltip'), appTextDefaults['home.cart_tooltip']);
    });

    test('مقدار خالی (فقط فضا) به پیش‌فرض برمی‌گردد', () {
      final n = AppTextsNotifier();
      n.replaceAll({'home.headline': '   '});
      expect(n.t('home.headline'), appTextDefaults['home.headline']);
    });

    test('cleanForStore خالی‌ها و کلیدهای ناشناس را حذف می‌کند', () {
      final out = AppTextsNotifier.cleanForStore({
        'home.headline': '  متن  ',
        'cake.title': '',
        'unknown.key': 'چیزی',
      });
      expect(out, {'home.headline': 'متن'});
    });
  });

  group('AppTextsService — ذخیره/بارگذاری', () {
    test('decodeTexts فقط کلیدهای شناخته‌شده را قبول می‌کند', () {
      final m = AppTextsService.decodeTexts(
          '{"home.headline":"تست","key.nahad":"x","cake.title":""}');
      expect(m, {'home.headline': 'تست'});
    });

    test('decodeTexts خراب → خالی', () {
      expect(AppTextsService.decodeTexts('not-json'), isEmpty);
      expect(AppTextsService.decodeTexts(''), isEmpty);
      expect(AppTextsService.decodeTexts('[1,2]'), isEmpty);
    });

    test('ذخیره و بارگذاری آفلاین (آینه لوکال)', () async {
      SharedPreferences.setMockInitialValues({});
      final svc = AppTextsService();
      await svc.save({'home.headline': 'دسرهای تازه 🍰'});
      expect((await svc.load())['home.headline'], 'دسرهای تازه 🍰');
    });

    test('بارگذاری با هیچ داده‌ای → خالی (پیش‌فرض‌ها در UI می‌آیند)', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await AppTextsService().load(), isEmpty);
    });
  });

  group('کیک‌ساز — متن‌های سفارشی در UI', () {
    Widget wrap(AppTextsNotifier n, Widget child) => AppTexts(
          notifier: n,
          child: MaterialApp(home: child),
        );

    testWidgets('عنوان و متن‌های بخش‌ها از متن‌های سفارشی می‌آید',
        (tester) async {
      final n = AppTextsNotifier();
      n.replaceAll({
        'cake.title': 'کیک تولد خانگی شما 🎉',
        'cake.weight_title': 'چقدر کیک؟',
        'cake.flavor_title': 'طعم دلخواه',
        'cake.filling_title': 'داخل کیک',
        'cake.add_button': 'بگذارش توی سبد',
      });

      await tester.pumpWidget(
          wrap(n, const CustomCakeScreen(username: 'tester')));
      await tester.pumpAndSettle();

      expect(find.text('کیک تولد خانگی شما 🎉'), findsOneWidget);
      expect(find.text('چقدر کیک؟'), findsOneWidget);
      expect(find.text('طعم دلخواه'), findsOneWidget);
      expect(find.text('داخل کیک'), findsOneWidget);
    });

    testWidgets('خلاصه سفارش از متن‌های مدیر ساخته می‌شود', (tester) async {
      final n = AppTextsNotifier();
      n.replaceAll({
        'cake.summary_prefix': 'کیک',
        'cake.summary_middle': 'با فیلینگ',
        'cake.weight_unit': 'کیلوگرم',
      });

      await tester.pumpWidget(
          wrap(n, const CustomCakeScreen(username: 'tester')));
      await tester.pumpAndSettle();

      // خلاصه داخل کارت پایین صفحه باید شامل متن‌های سفارشی باشد
      expect(
        find.textContaining('با فیلینگ'),
        findsWidgets,
      );
      expect(find.textContaining('کیلوگرم'), findsWidgets);
    });
  });
}
