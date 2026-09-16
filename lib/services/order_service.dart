import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/order.dart';
import '../utils/format.dart';

/// ذخیره سفارش‌ها فعلا لوکال (لیست JSON). با اتصال سوپابیس همین متدها به جدول orders وصل می‌شوند.
/// (نکته: تا مهاجرت به Supabase Auth، سفارش‌ها فقط روی دستگاهِ ثبت‌کننده دیده می‌شوند.)
class OrderService {
  static const _k = 'qand_orders';

  /// همه سفارش‌ها.
  /// - اگر [isAdmin] درست باشد، همه سفارش‌ها برمی‌گردد (فقط پنل مدیر باید
  ///   این را با true صدا بزند، بعد از بررسی AuthService().isAdmin()).
  /// - اگر [forUser] داده شود فقط سفارش‌های همان کاربر برمی‌گردد.
  /// - اگر هیچ‌کدام داده نشود، لیست خالی برمی‌گردد تا به‌اشتباه همه
  ///   سفارش‌ها به کاربر عادی نشت نکند (قبلا all() بدون آرگومان همه را می‌داد).
  /// نکته حریم خصوصی: سفارش‌های قدیمی بدون owner ('') فقط به مدیر نشان داده
  /// می‌شوند تا هیچ کاربری سفارش کاربر دیگر را نبیند. داده‌ای گم نمی‌شود
  /// (مدیر همه را می‌بیند) ولی نشت حریم خصوصی هم رخ نمی‌دهد.
  Future<List<QandOrder>> all({String? forUser, bool isAdmin = false}) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList(_k) ?? [];
    final list = <QandOrder>[];
    for (final s in raw) {
      try {
        list.add(_decode(s));
      } catch (_) {
        // رکورد خراب را نادیده بگیر تا کل لیست کرش نکند
      }
    }
    if (isAdmin) return list;
    if (forUser == null) return <QandOrder>[];
    // فقط سفارش‌های خود کاربر — رکوردهای قدیمی بدون owner فقط برای مدیر
    return list.where((o) => o.owner == forUser).toList();
  }

  Future<void> add(QandOrder o) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList(_k) ?? [];
    raw.add(_encode(o));
    await p.setStringList(_k, raw);
  }

  /// نتیجه‌ی آپدیت وضعیت — تا UI بتواند خطای واقعی را نشان دهد نه پیام موفقیت کورکورانه.
  /// (از رشته استفاده می‌کنیم تا مدل ساده بماند.)
  static const updateOk = 'ok';
  static const updateNotFound = 'not_found';
  static const updateBadStatus = 'bad_status';
  static const updateBadPrice = 'bad_price';

  Future<String> updateStatus(String id, String status, {String? receiptPath, int? totalPrice}) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList(_k) ?? [];
    final list = <QandOrder>[];
    for (final s in raw) {
      try {
        list.add(_decode(s));
      } catch (_) {
        // نادیده گرفتن رکورد خراب
      }
    }
    final i = list.indexWhere((e) => e.id == id);
    if (i == -1) return updateNotFound;
    if (totalPrice != null && totalPrice <= 0) return updateBadPrice;
    // اعتبارسنجی وضعیت: فقط وضعیت‌های شناخته‌شده قبول است تا تایپو باعث گم‌شدن سفارش نشود
    const valid = {
      OrderStatuses.pending,
      OrderStatuses.awaitingPayment,
      OrderStatuses.receiptSent,
      OrderStatuses.approved,
      OrderStatuses.ready,
      OrderStatuses.delivered,
      OrderStatuses.cancelled,
    };
    if (!valid.contains(status)) return updateBadStatus;
    list[i] = list[i].copyWith(status: status, receiptPath: receiptPath, totalPrice: totalPrice);
    await p.setStringList(_k, list.map(_encode).toList());
    return updateOk;
  }

  /// یک سفارش با شناسه (برای رفرش صفحه پرداخت بعد از اعلام مبلغ توسط مدیر).
  /// null یعنی سفارش حذف/پیدا نشد — صفحه پرداخت باید پیام مناسب نشان دهد نه کرش.
  Future<QandOrder?> byId(String id) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList(_k) ?? [];
    for (final s in raw) {
      try {
        final o = _decode(s);
        if (o.id == id) return o;
      } catch (_) {
        // نادیده بگیر
      }
    }
    return null;
  }

  String _encode(QandOrder o) => jsonEncode({
        'id': o.id, 'productId': o.productId, 'productTitle': o.productTitle,
        'qty': o.qty, 'persons': o.persons, 'fullName': o.fullName,
        'phone': o.phone, 'address': o.address, 'deliveryDate': o.deliveryDate,
        'note': o.note, 'status': o.status, 'totalPrice': o.totalPrice,
        'receiptPath': o.receiptPath, 'createdAt': o.createdAt,
        'owner': o.owner,
      });

  QandOrder _decode(String s) {
    final m = jsonDecode(s) as Map<String, dynamic>;
    return QandOrder(
      id: '${m['id']}', productId: '${m['productId']}', productTitle: '${m['productTitle']}',
      qty: parseIntSafe(m['qty'], 1), persons: parseIntSafe(m['persons'], 1),
      fullName: '${m['fullName'] ?? ''}', phone: '${m['phone'] ?? ''}', address: '${m['address'] ?? ''}',
      deliveryDate: '${m['deliveryDate'] ?? ''}', note: '${m['note'] ?? ''}',
      status: '${m['status'] ?? OrderStatuses.pending}', totalPrice: parseIntSafe(m['totalPrice'], 0),
      receiptPath: m['receiptPath'] as String?, createdAt: '${m['createdAt'] ?? ''}',
      owner: '${m['owner'] ?? ''}',
    );
  }
}
