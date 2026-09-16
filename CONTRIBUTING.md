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
- EN: Never weaken the Supabase RLS policies in `supabase/schema.sql` (no `for all using (true)` client policies).
- FA: پالیسی‌های RLS در `supabase/schema.sql` را سست نکن (هیچ پالیسی بازِ کلاینتی).
- EN: Secrets (`key.properties`, keystores, service keys) must never be committed.
- FA: هرگز secret ها (key.properties، کی‌استور، کلیدهای سرویس) کامیت نشوند.
- EN: Commit `pubspec.lock` for reproducible CI builds.
- FA: `pubspec.lock` را برای تکرارپذیری بیلد CI کامیت نگه دار.
