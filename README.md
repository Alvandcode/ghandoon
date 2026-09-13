# qand-app (Confectionery Ordering)

[![Stars](https://img.shields.io/github/stars/Alvandcode/qand-app?style=flat-square)](https://github.com/Alvandcode/qand-app/stargazers) [![License](https://img.shields.io/github/license/Alvandcode/qand-app?style=flat-square)](./LICENSE) [![Last commit](https://img.shields.io/github/last-commit/Alvandcode/qand-app?style=flat-square)](https://github.com/Alvandcode/qand-app/commits)

> Flutter ordering app for a confectionery (Android 7-17) with Supabase backend — categories, order form, receipt upload, admin panel.

<div dir="rtl">

## اپ سفارش قنادی قند

اپلیکیشن سفارش قنادی با فلاتر برای اندروید ۷ تا ۱۷ با بک‌اند سوپابیس؛ دسته‌بندی محصولات، فرم سفارش، آپلود فیش و پنل مدیریت.

</div>

---

# قنادی قند 🍰 — qand-app

اپ اندروید (7 تا 15) سفارش قنادی با Flutter + Supabase (با fallback آفلاین).

## فلو
1. انتخاب دسته (کیک خونگی / کوکی / بیسکوییت / کیک تولد) → ادامه
2. جزئیات + مواد تشکیل‌دهنده → لینک سفارش
3. فرم سفارش (تعداد، نفرات، نام، موبایل، آدرس دقیق حداقل ۱۰ کاراکتر، تاریخ شمسی)
4. انتظار اعلام مبلغ توسط مدیر (تا اعلام نشود دکمه پرداخت قفل است) → پرداخت کارت‌به‌کارت (شماره کارت از پنل مدیر قابل تغییر است) + زرین‌پال (پیش‌فرض خالی، بعدا)
5. آپلود فیش → تایید مدیر → تحویل

## اجرا
```bash
flutter pub get
flutter analyze
flutter test
flutter run
# بیلد:
flutter build apk --release
```
بدون نصب فلاتر هم با push به main در GitHub Actions تست‌ها + تحلیل اجرا و فایل `app-release.apk` ساخته می‌شود (تب Actions → دانلود qand-apk).

## سوپابیس (اختیاری ولی پیشنهادی)
1. پروژه بساز در supabase.com
2. `supabase/schema.sql` را در SQL Editor اجرا کن (اجرای چندباره امن است؛ سید تکراری نمی‌سازد)
3. در Storage باکت‌های `product-images` (public) و `receipts` را بساز
4. اجرا با:
```bash
flutter run --dart-define=SUPABASE_URL=https://xyz.supabase.co --dart-define=SUPABASE_ANON_KEY=KEY
```
تا وقتی وصل نیست اپ با حافظه لوکال (دمو) کار می‌کند.

### وضعیت اتصال (شفاف)
- ✅ محصولات: سوپابیس (جدول `products`) با fallback دمو
- ✅ تنظیمات (کارت/زرین‌پال): سوپابیس (`app_settings` ردیف 1) با آینه لوکال
- ⏳ سفارش‌ها: فعلا لوکال (SharedPreferences) — چون احراز هویت هنوز لوکال است و نگاشت امن `owner` به `user_id` نیاز به مهاجرت به Supabase Auth دارد. بعد از مهاجرت، همین `OrderService` به جدول `orders` وصل می‌شود.
- ⏳ چت: تاریخچه لوکال ماندگار (200 پیام آخر) — پیام زنده مدیر بعد از اتصال جدول `messages`.

## ادمین
- ورود با `admin / 1234` (اولین ورود ساخته می‌شود)
- تب مدیر: تغییر وضعیت سفارش، ثبت مبلغ+کارت، تایید فیش، ویرایش شماره کارت/زرین‌پال از «تنظیمات»
- شماره کارت پیش‌فرض: `6037-9911-1234-5678` — از پنل عوض کن

## پشتیبانی اندروید 7 تا 15
`minSdk 24` و `targetSdk 35` در `android/app/build.gradle` تنظیم شده.

## امضای ریلیز (مهم برای انتشار)
- بیلد CI به‌صورت پیش‌فرض با کلید دیباگ امضا می‌شود (نصب مستقیم OK، انتشار در استور نه).
- برای انتشار: `android/key.properties.example` را به `android/key.properties` کپی و مقادیر واقعی را بگذار (این فایل هرگز کامیت نمی‌شود).
- در GitHub هم می‌توانی secrets های `ANDROID_KEYSTORE_BASE64/PASSWORD/ALIAS` را بگذاری تا ریلیز CI با کی‌استور واقعی امضا شود.

## عکس‌ها
ببین: `assets/README_ASSETS.md`

---

## Contributing / مشارکت

- EN: Issues and Pull Requests are welcome. Please see `CONTRIBUTING.md`.
- FA: برای گزارش مشکل یا پیشنهاد قابلیت جدید، لطفا ایشو یا پول‌ریکوئست ثبت کنید.

## License / لایسنس

MIT — see [LICENSE](./LICENSE).

## Contact / ارتباط

- Telegram: https://t.me/a_c_official
- Website: https://alvandcode.github.io
