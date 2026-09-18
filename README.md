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
- ✅ سفارش‌ها: دوحالته — اگر سوپابیس وصل باشد جدول `orders` منبع حقیقت است (مدیر و مشتری روی دو گوشی همدیگر را می‌بینند) با آینه لوکال برای آفلاین؛ وگرنه کاملاً لوکال. ستون‌های جدید (`tracking_code` ،`fulfillment` ،`delivery_fee` ،`items_summary` ،`cake_options`) با اجرای دوباره `schema.sql` اضافه می‌شوند.
- ✅ اعلان: محلی سر رفرش (بدون نیاز به چیزی) + پوش واقعی FCM بعد از راه‌اندازی یک‌باره بخش «پوش واقعی» پایین.
- ⏳ چت: تاریخچه لوکال ماندگار (200 پیام آخر)؛ تا اتصال جدول `messages`، چت در «حالت دمو» است و هدرش همین را صادقانه نشان می‌دهد.

### امنیت سوپابیس (مهم)
`schema.sql` حالا RLS سفت دارد:
- `products` و `app_settings`: خواندن عمومی، نوشتن فقط با service_role.
- تغییر شماره کارت/زرین‌پال فقط از داشبورد سوپابیس (Table Editor) انجام شود — نه از اپ.
- `orders`/`messages`/`profiles`: تا مهاجرت به Supabase Auth هیچ دسترسی کلاینتی باز نیست.

## پوش واقعی (FCM) — راه‌اندازی یک‌باره

بدون این قدم‌ها، اعلان فقط «محلی سر رفرش» کار می‌کند (مدیر با باز کردن پنل، مشتری با باز کردن پیگیری). برای پوش واقعی حتی وقتی اپ بسته است:

**۱. فایربیس (کنسول گوگل):**
1. در [Firebase Console](https://console.firebase.google.com) پروژه بساز.
2. Add app → Android با package name دقیق `com.qand.app` (از `android/app/build.gradle`).
3. فایل `google-services.json` را دانلود و دقیقاً در `android/app/google-services.json` بگذار (کامیت نشود — در `.gitignore` است).
   خط‌های گردل لازم از قبل در ریپو هست و خودکار فقط وقتی فعال می‌شوند که همین فایل وجود داشته باشد؛ چیزی را دستی عوض نکن.
4. در کنسول فایربیس → Project settings → Service accounts → Generate new private key (فایل JSON).

**۲. سوپابیس (Edge Functions):**
```bash
supabase functions deploy push-fanout
supabase functions deploy register-push-token
supabase secrets set FIREBASE_SERVICE_ACCOUNT_JSON='<محتوای کامل فایل JSON مرحله قبل>'
# اختیاری ولی پیشنهادی:
supabase secrets set PUSH_WEBHOOK_SECRET='<یک رشته تصادفی بلند>'
```
(فایل‌ها: `supabase/functions/push-fanout` و `register-push-token` — آماده‌اند.)

**۳. وب‌هوک‌های دیتابیس (داشبورد سوپابیس → Database → Webhooks → Create):**
1. وب‌هوک `orders-insert`: جدول `orders`، رویداد `INSERT`، آدرس `https://xyz.supabase.co/functions/v1/push-fanout`، هدر `x-webhook-secret` (همان مقدار مرحله ۲).
2. وب‌هوک `orders-update`: جدول `orders`، رویداد `UPDATE`، همان آدرس و هدر.
3. `supabase/schema.sql` را دوباره اجرا کن (ستون `profiles.fcm_token` اضافه می‌شود؛ اجرای چندباره امن است).

**۴. تست:**
- اپ را با `--dart-define` سوپابیس روی دو گوشی نصب کن (یکی مدیر، یکی مشتری).
- مشتری سفارش بدهد → روی گوشی مدیر (حتی بسته) اعلان «سفارش جدید 🧁» می‌آید.
- مدیر مبلغ/وضعیت را عوض کند → روی گوشی مشتری اعلان فارسی وضعیت می‌آید.
- زدن روی اعلان، تب درست (پیگیری/مدیر) را باز می‌کند.

نکته فنی: تاپیک مدیر `orders_admin` و تاپیک هر کاربر `user_<نام‌کاربری-encodeشده>` است (منطق مشترک در `lib/utils/push_topics.dart` و داخل فایل `supabase/functions/push-fanout/index.ts` — هر دو تک‌فایل و بدون import هستند تا مستقیم در ادیتور داشبورد بچسبند؛ اگر عوض کردی هر دو را عوض کن).

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
