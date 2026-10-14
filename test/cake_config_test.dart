import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qand_app/models/app_texts.dart';
import 'package:qand_app/models/cake_config.dart';
import 'package:qand_app/screens/custom_cake_screen.dart';
import 'package:qand_app/services/cake_config_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CakeConfig — JSON و پیش‌فرض‌ها', () {
    test('پیش‌فرض: طعم/فیلینگ/شمع وجود دارد', () {
      const c = defaultCakeConfig;
      expect(c.sections.length, 3);
      expect(c.sections[0].title, 'طعم کیک');
      expect(c.sections[0].options.any((o) => o.label == 'ردولوت'), isTrue);
      expect(c.sections[0].options.any((o) => o.label == 'مغزیجات'), isTrue);
      // فیلینگ سه زیربخش دارد
      expect(c.sections[1].subsections.length, 3);
      expect(c.sections[1].subsections.map((s) => s.title),
          containsAll(['خامه', 'میوه', 'مغزیجات']));
      // شمع زیرشاخه دارد
      final candle = c.sections[2];
      final yes = candle.options.firstWhere((o) => o.label.contains('بله'));
      expect(yes.children.length, 1);
      expect(yes.children.first.options.length, 2);
    });

    test('رفت‌وبرگشت JSON بدون تغییر', () {
      const c = defaultCakeConfig;
      final back = CakeConfig.fromJson(
          Map<String, dynamic>.from(jsonDecode(jsonEncode(c.toJson()))));
      expect(back.pricePerKg, c.pricePerKg);
      expect(back.leadDays, c.leadDays);
      expect(back.weights, c.weights);
      expect(back.sections.length, c.sections.length);
      expect(back.sections[0].options.length, c.sections[0].options.length);
      // زیرشاخه گزینه مغزیجات حفظ شود
      final nuts = back.sections[0].options.firstWhere((o) => o.label == 'مغزیجات');
      expect(nuts.children.first.options.length, 6);
    });

    test('ورودی خراب → پیش‌فرض امن', () {
      final c = CakeConfig.fromJson({
        'pricePerKg': 'abc',
        'leadDays': -5,
        'weights': ['x', -2, 0, 3],
        'sections': 'nope',
      });
      expect(c.pricePerKg, 380000);
      expect(c.leadDays, 3);
      expect(c.weights, contains(3));
      expect(c.weights, isNot(contains(-2)));
      expect(c.sections, isEmpty);
    });

    test('priceFor فقط وزن‌های مجاز را قبول می‌کند', () {
      const c = defaultCakeConfig;
      expect(c.priceFor(2), 760000);
      expect(c.priceFor(1.5), 570000);
      expect(c.priceFor(2.7), isNull);
    });

    test('idهای درخت یکتا هستند', () {
      final ids = defaultCakeConfig.allIds();
      final flat = <String>{};
      void walk(List<CakeSection> list) {
        for (final s in list) {
          flat.add(s.id);
          for (final o in s.options) {
            flat.add(o.id);
            for (final c in o.children) {
              walk([c]);
            }
          }
          walk(s.subsections);
        }
      }

      walk(defaultCakeConfig.sections);
      expect(flat.length, ids.length);
      expect(flat.length, defaultCakeConfig.allIds().length);
    });
  });

  group('CakeConfigService — ذخیره/بارگذاری', () {
    test('آفلاین: ذخیره و بازخوانی', () async {
      SharedPreferences.setMockInitialValues({});
      final svc = CakeConfigService();
      final edited = defaultCakeConfig.copyWith(
        pricePerKg: 500000,
        sections: const [
          CakeSection(id: 's1', title: 'فقط شکلاتی', options: [
            CakeOption(id: 'o1', label: 'شکلاتی')
          ])
        ],
      );
      await svc.save(edited);
      final back = await svc.load();
      expect(back.pricePerKg, 500000);
      expect(back.sections.length, 1);
      expect(back.sections.first.options.first.label, 'شکلاتی');
    });

    test('بی‌داده → پیش‌فرض', () async {
      SharedPreferences.setMockInitialValues({});
      final loaded = await CakeConfigService().load();
      expect(loaded.sections.length, 3);
    });

    test('decodeConfig خراب → null', () {
      expect(CakeConfigService.decodeConfig('not-json'), isNull);
      expect(CakeConfigService.decodeConfig(''), isNull);
      expect(CakeConfigService.decodeConfig('[1]'), isNull);
    });

    test('uniqueId تکراری نمی‌سازد', () {
      final taken = {'opt_1', 'opt_2'};
      expect(CakeConfigService.uniqueId(taken, 'opt'), 'opt_3');
    });
  });

  group('کیک‌ساز — رندر داینامیک', () {
    Future<void> pump(WidgetTester tester, CakeConfig cfg) async {
      SharedPreferences.setMockInitialValues({
        'cake_config_v1': jsonEncode(cfg.toJson()),
      });
      // صفحه بلند تا همه بخش‌ها بدون اسکرول رندر شوند
      tester.view.physicalSize = const Size(1000, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(AppTexts(
        notifier: AppTextsNotifier(),
        child: const MaterialApp(home: CustomCakeScreen(username: 't')),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('گزینه‌های بخش‌ها نمایش داده می‌شوند', (tester) async {
      await pump(tester, defaultCakeConfig);
      expect(find.text('طعم کیک'), findsOneWidget);
      expect(find.text('وانیلی'), findsOneWidget);
      expect(find.text('شمع'), findsOneWidget);
    });

    testWidgets('زیرشاخه گزینه فقط بعد از انتخاب باز می‌شود', (tester) async {
      await pump(tester, defaultCakeConfig);
      // قبل از انتخاب، «مغزیجات کدام باشد؟» نباید باشد
      expect(find.text('مغزیجات کدام باشد؟'), findsNothing);

      await tester.tap(find.text('مغزیجات').first);
      await tester.pumpAndSettle();

      expect(find.text('مغزیجات کدام باشد؟'), findsOneWidget);
      expect(find.text('بادام'), findsWidgets);
    });

    testWidgets('شمع: انتخاب بله زیرشاخه نوع شمع را باز می‌کند',
        (tester) async {
      await pump(tester, defaultCakeConfig);
      expect(find.text('نوع شمع'), findsNothing);
      await tester.tap(find.text('بله، شمع می‌خوام'));
      await tester.pumpAndSettle();
      expect(find.text('نوع شمع'), findsOneWidget);
      expect(find.text('شمع تکی'), findsOneWidget);
      expect(find.text('شمع چندتایی'), findsOneWidget);
    });

    testWidgets('زیربخش‌های فیلینگ جدا نمایش داده می‌شوند', (tester) async {
      await pump(tester, defaultCakeConfig);
      expect(find.text('خامه'), findsOneWidget);
      expect(find.text('میوه'), findsOneWidget);
      // «مغزیجات» هم طعم است هم زیربخش فیلینگ → دو بار
      expect(find.text('مغزیجات'), findsNWidgets(2));
      expect(find.text('خامه وانیلی'), findsOneWidget);
    });
  });
}