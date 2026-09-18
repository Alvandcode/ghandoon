import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/order.dart';

/// تشخیص خالص تغییرات سفارش (بدون وابستگی به پلاگین — تست‌پذیر).
class OrderChangeDetector {
  /// شناسه سفارش‌هایی که در لیست جدید هستند ولی در قبلی نبودند.
  static List<String> newOrderIds({
    required List<QandOrder> oldList,
    required List<QandOrder> newList,
  }) {
    final oldIds = {for (final o in oldList) o.id};
    return [for (final o in newList) if (!oldIds.contains(o.id)) o.id];
  }

  /// سفارش‌هایی که وضعیتشان عوض شده (id مشترک، status متفاوت).
  static List<QandOrder> statusChanged({
    required List<QandOrder> oldList,
    required List<QandOrder> newList,
  }) {
    final oldById = {for (final o in oldList) o.id: o.status};
    return statusChangedFromMap(oldStatus: oldById, newList: newList);
  }

  /// همان بالا ولی با نقشه id→status (برای صفحه پیگیری که فقط نقشه نگه می‌دارد).
  static List<QandOrder> statusChangedFromMap({
    required Map<String, String> oldStatus,
    required List<QandOrder> newList,
  }) {
    return [
      for (final o in newList)
        if (oldStatus.containsKey(o.id) && oldStatus[o.id] != o.status) o
    ];
  }
}

/// اعلان محلی (روی دستگاه — بدون نیاز به سرور/فایربیس).
/// - مدیر: با هر بار باز شدن پنل، سفارش‌های جدید اعلان می‌شوند.
/// - مشتری: با هر رفرش پیگیری، تغییر وضعیت سفارش‌هایش اعلان می‌شود.
/// مسیر ارتقا به پوش واقعی (FCM): همین متدها را از FirebaseMessaging.onMessage
/// صدا بزن؛ امضای متدها عوض نمی‌شود. راهنما در README.
class NotificationService {
  static final NotificationService _i = NotificationService._();
  factory NotificationService() => _i;
  NotificationService._();

  /// وقتی کاربر روی اعلان (محلی یا FCM) می‌زند، شناسه سفارش این‌جا می‌آید.
  /// PushService آن را می‌خواند و صفحه درست را باز می‌کند.
  static void Function(String orderId)? onTap;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      await _plugin.initialize(
        settings: const InitializationSettings(android: android),
        onDidReceiveNotificationResponse: (r) {
          final id = (r.payload ?? '').trim();
          if (id.isNotEmpty) onTap?.call(id);
        },
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  Future<void> showNewOrder(QandOrder o) async {
    await _show(
      id: o.id.hashCode,
      title: 'سفارش جدید 🧁',
      body: '${o.displayItems} — ${o.displayCode}',
      payload: o.id,
    );
  }

  Future<void> showStatusChanged(QandOrder o) async {
    await _show(
      id: o.id.hashCode ^ 0x9e37,
      title: 'سفارش ${o.displayCode} — ${OrderStatuses.fa(o.status)}',
      body: o.displayItems,
      payload: o.id,
    );
  }

  /// نمایش دستی پیام FCM در فورگراند (در بک‌گراند خودِ FCM نشان می‌دهد).
  Future<void> showFromPush({
    required String title,
    required String body,
    required String orderId,
  }) async {
    await _show(
      id: orderId.hashCode ^ 0x51ab,
      title: title,
      body: body,
      payload: orderId,
    );
  }

  Future<void> _show({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      await init();
      if (!_ready) return;
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'qand_orders',
            'سفارش‌ها',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        payload: payload,
      );
    } catch (_) {
      // اعلان نباید هیچ فلویی را خراب کند
    }
  }
}
