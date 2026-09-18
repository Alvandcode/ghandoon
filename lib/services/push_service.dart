import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/push_topics.dart';
import 'notification_service.dart';
import 'supabase_service.dart';

/// هندلر بک‌گراند FCM — باید تابع top-level بماند (در main ثبت می‌شود).
@pragma('vm:entry-point')
Future<void> fcmBackgroundHandler(RemoteMessage message) async {
  // پیام‌های دارای بخش notification را خودِ سیستم در بک‌گراند نشان می‌دهد؛
  // این‌جا فقط کرش نکن.
}

/// پوش واقعی (FCM) + fallback اعلان محلی.
/// - اگر فایربیس پیکربندی نشده باشد (google-services.json نیست)، init
///   خطا را قورت می‌دهد و false برمی‌گرداند؛ اپ با همان اعلان‌های محلی
///   سر رفرش کار می‌کند و هیچ‌چیز کرش نمی‌کند.
/// - مدیر عضو تاپیک [adminPushTopic] می‌شود (سفارش جدید).
/// - هر کاربر عضو تاپیک شخصی خودش می‌شود (تغییر وضعیت سفارش‌هایش).
class PushService {
  static final PushService _i = PushService._();
  factory PushService() => _i;
  PushService._();

  bool _ready = false;
  bool _listenersSet = false;
  String? _tapOrderId;

  bool get isReady => _ready;

  /// شناسه سفارشی که با زدن روی اعلان باید باز شود (یک‌بار مصرف).
  String? consumeTap() {
    final id = _tapOrderId;
    _tapOrderId = null;
    return (id == null || id.isEmpty) ? null : id;
  }

  Future<bool> init({required String username, required bool isAdmin}) async {
    NotificationService.onTap = (id) => _tapOrderId = id;
    try {
      await Firebase.initializeApp();
    } catch (_) {
      return false; // فایربیس پیکربندی نشده → حالت محلی
    }
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      final topic = pushTopicForUser(username);
      await messaging.subscribeToTopic(topic);
      if (isAdmin) {
        await messaging.subscribeToTopic(adminPushTopic);
      } else {
        await messaging.unsubscribeFromTopic(adminPushTopic);
      }
      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await _saveToken(username, token);
      }
      messaging.onTokenRefresh.listen((t) => _saveToken(username, t));
      if (!_listenersSet) {
        _listenersSet = true;
        FirebaseMessaging.onMessage.listen((m) {
          final d = pushDisplayFromData(
            Map<String, String>.from(m.data),
            notificationTitle: m.notification?.title,
            notificationBody: m.notification?.body,
          );
          // ignore: unawaited_futures
          NotificationService().showFromPush(
            title: d.title,
            body: d.body,
            orderId: d.orderId,
          );
        });
        FirebaseMessaging.onMessageOpenedApp.listen((m) {
          final d = pushDisplayFromData(Map<String, String>.from(m.data));
          if (d.orderId.isNotEmpty) _tapOrderId = d.orderId;
        });
        final initial = await messaging.getInitialMessage();
        if (initial != null) {
          final d = pushDisplayFromData(
              Map<String, String>.from(initial.data));
          if (d.orderId.isNotEmpty) _tapOrderId = d.orderId;
        }
      }
      _ready = true;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _saveToken(String username, String token) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString('fcm_token', token);
    } catch (_) {}
    final client = SupabaseService.clientOrNull();
    if (client == null) {
      await _savePending(username, token);
      return;
    }
    try {
      await client.functions.invoke(
        'register-push-token',
        body: {'username': username.trim(), 'token': token},
      );
    } catch (_) {
      await _savePending(username, token);
    }
  }

  Future<void> _savePending(String username, String token) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString('pending_fcm_token_$username', token);
    } catch (_) {}
  }
}
