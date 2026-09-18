# قوانین ProGuard/R8 برای بیلد ریلیز
# فلاتر خودش قوانین پیش‌فرض لازم را تزریق می‌کند؛ این فقط برای کتابخانه‌های پرقلعه است.

# supabase / gotrue / postgrest (dart HTTP layer ها native code ندارند ولی برای اطمینان)
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# جلوگیری از هشدارهای بی‌خطر متاور داده‌های jackson/okhttp اگر در درخت وابستگی‌ها باشند
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**

# موتور فلاتر به کلاس‌های Play Core ارجاع می‌دهد که فقط در نصب از گوگل‌پلی لازم‌اند؛
# در APK نصب مستقیم غایب‌اند و R8 نباید به‌خاطرشان بیلد را بشکند.
-dontwarn com.google.android.play.core.**
