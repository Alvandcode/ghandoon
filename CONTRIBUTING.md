# Contributing / مشارکت

EN: Thanks for your interest! Issues and Pull Requests are welcome.
FA: برای گزارش مشکل یا پیشنهاد قابلیت جدید، لطفا ایشو یا پول‌ریکوئست ثبت کنید.

## قبل از ارسال PR / Before opening a PR

```bash
flutter pub get
flutter analyze --fatal-infos   # باید بدون خطا/هشدار باشد
flutter test                    # همه تست‌ها باید سبز باشند
```

## قواعد / Guidelines

- EN: Keep the offline-first behavior: the app must never crash when Supabase is unreachable.
- FA: رفتار offline-first را حفظ کن؛ اپ هیچ‌وقت نباید وقتی سوپابیس در دسترس نیست کرش کند.
- EN: Keep RLS tight in `supabase/schema.sql`. The only allowed open client write
  policy is `products` (`admin products write`) — needed because the admin panel
  has no Supabase Auth yet. Do not re-open `orders`/`messages`/`profiles`/`app_settings`.
- FA: پالیسی‌های RLS در `supabase/schema.sql` را سفت نگه دار. تنها پالیسی نوشتنِ بازِ
  مجاز `products` است (`admin products write`) چون پنل مدیر هنوز Supabase Auth ندارد.
  `orders`/`messages`/`profiles`/`app_settings` را باز نکن.
- EN: Secrets (`key.properties`, keystores, service keys) must never be committed.
- FA: هرگز secret ها (key.properties، کی‌استور، کلیدهای سرویس) کامیت نشوند.
- EN: Commit `pubspec.lock` for reproducible CI builds.
- FA: `pubspec.lock` را برای تکرارپذیری بیلد CI کامیت نگه دار.
