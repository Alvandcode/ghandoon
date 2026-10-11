import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'models/app_texts.dart';
import 'services/app_texts_service.dart';
import 'theme/qand_theme.dart';
import 'services/push_service.dart';
import 'services/supabase_service.dart';
import 'screens/splash_screen.dart';

/// کلید سراسری ناوبری — برای باز کردن صفحه درست با زدن روی اعلان.
final appNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // edge-to-edge یکنواخت روی همه اندرویدها (دکمه‌ای/ژستی/شفاف):
  // محتوا تا لبه می‌رود و صفحات با SafeArea/padding خودشان را جمع می‌کنند.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));
  // اگر کلید سوپابیس داده شده باشد وصل شو، وگرنه آفلاین ادامه بده
  await SupabaseService.initIfConfigured();
  // متن‌های قابل‌ویرایش (مدیر از پنل عوض می‌کند) — اگر خطا داد، پیش‌فرض‌ها
  final textsNotifier = AppTextsNotifier();
  try {
    textsNotifier.replaceAll(await AppTextsService().load());
  } catch (_) {
    textsNotifier.fillDefaults();
  }
  // هندلر بک‌گراند FCM (بدون فایربیس نادیده گرفته می‌شود، اپ کرش نمی‌کند)
  try {
    FirebaseMessaging.onBackgroundMessage(fcmBackgroundHandler);
  } catch (_) {}
  runApp(QandApp(texts: textsNotifier));
}

class QandApp extends StatelessWidget {
  final AppTextsNotifier texts;
  const QandApp({super.key, required this.texts});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: 'قندون',
      debugShowCheckedModeBanner: false,
      theme: QandTheme.light(),
      locale: const Locale('fa', 'IR'),
      supportedLocales: const [Locale('fa', 'IR'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        // متن‌های قابل‌ویرایش دور کل اپ (تغییرشان همه صفحه‌ها را تازه می‌کند).
        return AppTexts(
          notifier: texts,
          child: Builder(
            builder: (inner) {
              // سقف اندازه فونت سیستم تا با بزرگ‌نمایی زیاد، چیدمان به‌هم نریزد.
              // پدینگ سیستم (ناچ/نویگیشن) دست‌نخورده می‌ماند تا SafeArea درست کار کند.
              final mq = MediaQuery.of(inner);
              final clamped = mq.textScaler.clamp(
                  minScaleFactor: 0.8, maxScaleFactor: 1.3);
              return MediaQuery(
                data: mq.copyWith(textScaler: clamped),
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: child!,
                ),
              );
            },
          ),
        );
      },
      home: const SplashScreen(),
    );
  }
}
