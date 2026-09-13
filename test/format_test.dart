import 'package:flutter_test/flutter_test.dart';
import 'package:qand_app/utils/format.dart';

void main() {
  group('normalizeDigits', () {
    test('ارقام فارسی به انگلیسی', () {
      expect(normalizeDigits('۰۹۱۳۰۰۰۰۰۰۰'), '09130000000');
    });
    test('ارقام عربی به انگلیسی', () {
      expect(normalizeDigits('٠٩١٣٠٠٠٠٠٠٠'), '09130000000');
    });
    test('حذف کاما و فاصله', () {
      expect(normalizeDigits('450,000'), '450000');
      expect(normalizeDigits('۴۵۰٬۰۰۰'), '450000');
    });
  });

  group('isValidIranMobile', () {
    test('موبایل معتبر', () {
      expect(isValidIranMobile('09130000000'), isTrue);
      expect(isValidIranMobile('۰۹۱۳۰۰۰۰۰۰۰'), isTrue);
      expect(isValidIranMobile(' 09130000000 '), isTrue);
    });
    test('موبایل نامعتبر', () {
      expect(isValidIranMobile('9130000000'), isFalse);
      expect(isValidIranMobile('0913000000'), isFalse); // 10 رقم
      expect(isValidIranMobile('091300000000'), isFalse); // 12 رقم
      expect(isValidIranMobile(''), isFalse);
      expect(isValidIranMobile('abcdefghij'), isFalse);
    });
  });

  group('formatToman', () {
    test('جداکننده هزارگان', () {
      expect(formatToman(450000), '450,000 تومان');
      expect(formatToman(1000), '1,000 تومان');
      expect(formatToman(0), '0 تومان');
    });
  });

  group('parsePrice', () {
    test('مقادیر معتبر', () {
      expect(parsePrice('450000'), 450000);
      expect(parsePrice('450,000'), 450000);
      expect(parsePrice('۴۵۰۰۰۰'), 450000);
    });
    test('مقادیر نامعتبر', () {
      expect(parsePrice('abc'), isNull);
      expect(parsePrice(''), isNull);
      expect(parsePrice('0'), isNull); // کمتر از min
      expect(parsePrice('-5'), isNull);
      expect(parsePrice('9999999999999'), isNull); // بیشتر از max
    });
  });

  group('parseIntSafe', () {
    test('انواع ورودی', () {
      expect(parseIntSafe(5), 5);
      expect(parseIntSafe(5.9), 5);
      expect(parseIntSafe('42'), 42);
      expect(parseIntSafe('۴۲'), 42);
      expect(parseIntSafe(null, 7), 7);
      expect(parseIntSafe('خراب', 3), 3);
    });
  });
}
