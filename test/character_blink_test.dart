import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qand_app/widgets/character_blink.dart';

bool _isAssetImage(Widget w, String name) =>
    w is Image &&
    w.image is AssetImage &&
    (w.image as AssetImage).assetName == name;

void main() {
  testWidgets('ورود پخش می‌شود و بعد به فایل چشمک می‌رسد',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
          home: Scaffold(body: BlinkingCharacter(size: 100))),
    );

    // حین ورود: تصویر ثابت
    expect(
      find.byWidgetPredicate((w) => _isAssetImage(w, 'assets/images/chef.png')),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
          (w) => _isAssetImage(w, 'assets/images/chef_wink.webp')),
      findsNothing,
    );

    // جلو بردن ساعت تا پایان ورود (۷۵۰ms) + یک فریم برای setState
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(milliseconds: 100));

    // بعد از ورود: فایل متحرک چشمک جایگزین شده
    expect(
      find.byWidgetPredicate(
          (w) => _isAssetImage(w, 'assets/images/chef_wink.webp')),
      findsOneWidget,
    );
  });
}
