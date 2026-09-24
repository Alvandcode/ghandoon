import 'package:flutter_test/flutter_test.dart';
import 'package:qand_app/utils/push_topics.dart';
import 'package:qand_app/utils/responsive.dart';

void main() {
  group('push_topics — تاپیک FCM', () {
    test('نام انگلیسی ساده', () {
      expect(pushTopicForUser('ali'), 'user_ali');
      expect(pushTopicForUser('  Sara99  '), 'user_sara99');
    });

    test('نام فارسی percent-encode می‌شود و فقط کاراکتر مجاز دارد', () {
      final t = pushTopicForUser('علی');
      expect(t.startsWith('user_'), isTrue);
      expect(RegExp(r'^user_[a-zA-Z0-9\-_.~%]+$').hasMatch(t), isTrue);
      // «علی» = U+0639 U+0644 U+06CC → D8 B9 D9 84 DB 8C
      expect(t, 'user_%D8%B9%D9%84%DB%8C');
    });

    test('خالی و تاپیک مدیر', () {
      expect(pushTopicForUser('   '), 'user_guest');
      expect(adminPushTopic, 'orders_admin');
    });

    test('Dart و سرور باید یکی باشند (مقادیر ثابت)', () {
      // اگر این تست سبز است و topic.ts عوض نشده، دو طرف یکی‌اند.
      expect(pushTopicForUser('Reza_98'), 'user_reza_98');
      expect(pushTopicForUser('a b'), 'user_a%20b');
    });
  });

  group('pushDisplayFromData', () {
    test('title/body اعلان اولویت دارد', () {
      final d = pushDisplayFromData(
        {'orderId': 'abc', 'status': 'approved'},
        notificationTitle: 'سلام',
        notificationBody: 'متن',
      );
      expect(d.title, 'سلام');
      expect(d.body, 'متن');
      expect(d.orderId, 'abc');
    });

    test('fallback وقتی notification نیست + کلید قدیمی order_id', () {
      final d = pushDisplayFromData({'order_id': 'xyz'});
      expect(d.orderId, 'xyz');
      expect(d.title.isNotEmpty, isTrue);
      expect(d.body, contains('xyz'));
    });

    test('orderId خالی قابل تحمل', () {
      final d = pushDisplayFromData({});
      expect(d.orderId, '');
      expect(d.body.isNotEmpty, isTrue);
    });
  });

  group('Responsive', () {
    test('badge بین کف و سقف قفل می‌شود', () {
      expect(Responsive.badge(200, min: 110, max: 190, ratio: 0.42), 110);
      expect(Responsive.badge(1000, min: 110, max: 190, ratio: 0.42), 190);
      expect(Responsive.badge(360, min: 110, max: 190, ratio: 0.42),
          closeTo(151.2, 0.01));
    });

    test('isNarrow', () {
      expect(Responsive.isNarrow(320), isTrue);
      expect(Responsive.isNarrow(360), isFalse);
    });

    test('bottomSafe هرگز کمتر از inset نویگیشن نیست', () {
      // ناوبری دکمه‌ای معمول ~۴۸
      expect(Responsive.bottomSafe(48, extra: 16), 64);
      // ژستی/شفاف کوچک
      expect(Responsive.bottomSafe(0, extra: 16), 16);
      expect(Responsive.bottomSafe(24, extra: 8), 32);
      // منفی/خراب clamp می‌شود
      expect(Responsive.bottomSafe(-5, extra: 10), 10);
    });

    test('topSafe ناچ بلند را جمع می‌کند', () {
      expect(Responsive.topSafe(24, extra: 16), 40);
      expect(Responsive.topSafe(48, extra: 24), 72);
    });

    test('hPad روی عرض کم جمع‌وجورتر است', () {
      expect(Responsive.hPad(320), 12);
      expect(Responsive.hPad(400), 16);
    });
  });
}
