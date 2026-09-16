# qand-app (Confectionery Ordering)

[![Stars](https://img.shields.io/github/stars/Alvandcode/qand-app?style=flat-square)](https://github.com/Alvandcode/qand-app/stargazers) [![License](https://img.shields.io/github/license/Alvandcode/qand-app?style=flat-square)](./LICENSE) [![Last commit](https://img.shields.io/github/last-commit/Alvandcode/qand-app?style=flat-square)](https://github.com/Alvandcode/qand-app/commits)

> Flutter ordering app for a confectionery (Android 7–15) with Supabase backend — categories, order form, receipt upload, admin panel.

<div dir="rtl">

## اپ سفارش قنادی قند

اپلیکیشن سفارش قنادی با فلاتر برای اندروید ۷ تا ۱۵ با بک‌اند سوپابیس؛ دسته‌بندی محصولات، فرم سفارش، آپلود فیش و پنل مدیریت.

</div>

---

# قنادی قند 🍰 — qand-app

اپ اندروید (7 تا 15) سفارش قنادی با Flutter + Supabase (با fallback آفلاین).

## فلو
1. انتخاب دسته (کیک خونگی / کوکی / بیسکوییت / کیک تولد) → ادامه
2. جزئیات + مواد تشکیل‌دهنده → لینک سفارش
3. فرم سفارش (تعداد، نفرات، نام، موبایل، آدرس دقیق حداقل ۱۰ کاراکتر، تاریخ شمسی)
4. انتظار اعلام مبلغ توسط مدیر (تا اعلام نشود دکمه پرداخت قفل است) → پرداخت کارت‌به‌کارت (شماره کارت فقط از داشبورد سوپابیس تغییر می‌کند) + زرین‌پال (پیش‌فرض خالی، بعدا)
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
با push به main در GitHub Actions ابتدا `flutter analyze` و `flutter test` اجرا می‌شود و بعد فایل `app-release.apk` ساخته می‌شود (تب Actions → دانلود qand-apk؛ ریلیزها با تگ تاریخ‌دار ثبت می‌شوند).

## سوپابیس (اختیاری ولی پیشنهادی)
1. پروژه بساز در supabase.com
2. `supabase/schema.sql` را در SQL Editor اجرا کن (اجرای چندباره امن است؛ سید تکراری نمی‌سازد و پالیسی‌های باز نسخه‌های قبلی را خودکار حذف می‌کند)
3. در Storage باکت‌های `product-images` (public) و `receipts` را بساز
4. اجرا با:
```bash
flutter run --dart-define=SUPABASE_URL=https://xyz.supabase.co --dart-define=SUPABASE_ANON_KEY=KEY
```
تا وقتی وصل نیست اپ با حافظه لوکال (دمو) کار می‌کند.

### وضعیت اتصال (شفاف)
- ✅ محصولات: سوپابیس (جدول `products`) با fallback دمو فقط در حالت آفلاین/خطا. اگر سوپابیس وصل باشد و جدول خالی باشد، پیام «فعلاً محصولی نیست» نمایش داده می‌شود (نه محصولات دمو).
- ✅ تنظیمات (کارت/زرین‌پال): فقط-خواندنی از سوپابیس (`app_settings` ردیف 1) با آینه لوکال برای آفلاین.
- ⏳ سفارش‌ها: فعلا لوکال (SharedPreferences) — یعنی سفارش‌ها فقط روی دستگاه ثبت‌کننده دیده می‌شوند. مهاجرت به Supabase Auth لازم است تا چرخه‌ی سفارش بین مدیر و مشتری واقعا کار کند.
- ⏳ چت: تاریخچه لوکال ماندگار (200 پیام آخر)؛ تا اتصال جدول `messages`، چت در «حالت دمو» است و هدرش همین را صادقانه نشان می‌دهد.

### امنیت سوپابیس (مهم)
`schema.sql` حالا RLS سفت دارد:
- `products` و `app_settings`: خواندن عمومی، نوشتن فقط با service_role.
- تغییر شماره کارت/زرین‌پال فقط از داشبورد سوپابیس (Table Editor) انجام شود — نه از اپ.
- `orders`/`messages`/`profiles`: تا مهاجرت به Supabase Auth هیچ دسترسی کلاینتی باز نیست.

## ادمین
- ورود اولیه با اعتبارنامه پیش‌فرض ادمین (مستند در `lib/services/auth_service.dart`)؛ **بلافاصله بعد از اولین ورود عوضش کن.** (روی صفحه لاگین نمایش داده نمی‌شود)
- تب مدیر: تغییر وضعیت سفارش، ثبت مبلغ، تایید فیش (با بزرگ‌نمایی لمسی)، مشاهده تنظیمات
- شماره کارت پیش‌فرض فقط در حالت دمو/آفلاین نشان داده می‌شود — برای همه‌ی کاربران از داشبورد سوپابیس (`app_settings`) به‌روزش کن

## پشتیبانی اندروید 7 تا 15
`minSdk 24` و `targetSdk 35` در `android/app/build.gradle` تنظیم شده.
بکاپ ابری/انتقال دستگاه غیرفعال است (داده‌های حساس سفارش‌ها خارج از دستگاه کپی نمی‌شوند).

## امضای ریلیز (مهم برای انتشار)
- اگر `android/key.properties` وجود داشته باشد (محلی یا ساخته‌شده در CI از secrets)، بیلد release با همان امضا می‌شود.
- در نبود آن، بیلد با کلید دیباگ امضا می‌شود و هشدار واضح در لاگ بیلد چاپ می‌شود (نصب مستقیم OK، انتشار در استور نه).
- برای CI: secrets های `ANDROID_KEYSTORE_BASE64/PASSWORD/ALIAS/PASSWORD` را در GitHub بگذار؛ workflow خودش `key.properties` می‌سازد.
- `key.properties` و هر `*.jks` هرگز کامیت نمی‌شوند (در `.gitignore` هستند).

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
