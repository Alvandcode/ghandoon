import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/order.dart';
import '../utils/format.dart';
import 'supabase_service.dart';

/// سرویس سفارش دوحالته:
/// - اگر سوپابیس پیکربندی شده باشد → جدول `orders` منبع حقیقت است
///   (تا مدیر و مشتری روی دو گوشی جدا همدیگر را ببینند).
/// - وگرنه (حالت آفلاین/دمو) → همان لیست JSON لوکال قبلی.
/// - در حالت آنلاین، بعد از هر نوشتن موفق، آینه لوکال هم به‌روز می‌شود
///   تا آفلاین‌شدن بعدی اپ خالی نماند.
///
/// نکته حریم خصوصی (حالت لوکال): سفارش‌های قدیمی بدون owner ('') فقط به مدیر
/// نشان داده می‌شوند تا هیچ کاربری سفارش دیگری را نبیند.
class OrderService {
  static const _k = 'qand_orders';

  /// همه سفارش‌ها.
  /// - اگر [isAdmin] درست باشد، همه سفارش‌ها برمی‌گردد (فقط پنل مدیر باید
  ///   این را با true صدا بزند، بعد از بررسی AuthService().isAdmin()).
  /// - اگر [forUser] داده شود فقط سفارش‌های همان کاربر برمی‌گردد.
  /// - اگر هیچ‌کدام داده نشود، لیست خالی برمی‌گردد تا به‌اشتباه همه
  ///   سفارش‌ها به کاربر عادی نشت نکند.
  Future<List<QandOrder>> all({String? forUser, bool isAdmin = false}) async {
    final remote = await _remoteAll(forUser: forUser, isAdmin: isAdmin);
    if (remote != null) return remote;
    return _localAll(forUser: forUser, isAdmin: isAdmin);
  }

  /// ثبت سفارش. سفارشِ برگشتی (با id نهایی سرور + کد پیگیری) را برمی‌گرداند.
  /// اگر کد پیگیری خالی باشد، همین‌جا ساخته می‌شود.
  Future<QandOrder> add(QandOrder o) async {
    final order = o.trackingCode.isEmpty
        ? o.copyWith(trackingCode: generateTrackingCode())
        : o;
    final remote = await _remoteAdd(order);
    if (remote != null) {
      await _localUpsert(remote);
      return remote;
    }
    await _localAdd(order);
    return order;
  }

  /// نتیجه‌ی آپدیت وضعیت — تا UI بتواند خطای واقعی را نشان دهد نه پیام موفقیت کورکورانه.
  static const updateOk = 'ok';
  static const updateNotFound = 'not_found';
  static const updateBadStatus = 'bad_status';
  static const updateBadPrice = 'bad_price';
  static const cancelForbidden = 'forbidden';
  static const cancelNotAllowed = 'not_allowed';

  Future<String> updateStatus(String id, String status,
      {String? receiptPath, int? totalPrice}) async {
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
    if (totalPrice != null && totalPrice <= 0) return updateBadPrice;

    final client = SupabaseService.clientOrNull();
    if (client != null) {
      try {
        final patch = <String, dynamic>{'status': status};
        if (receiptPath != null) patch['receipt_url'] = receiptPath;
        if (totalPrice != null) patch['total_price'] = totalPrice;
        final rows = await client
            .from('orders')
            .update(patch)
            .eq('id', id)
            .select();
        if ((rows as List).isEmpty) return updateNotFound;
        final fresh =
            QandOrderMapper.fromMap(Map<String, dynamic>.from(rows.first as Map));
        await _localUpsert(fresh);
        return updateOk;
      } catch (_) {
        // خطای شبکه/RLS → ادامه با لوکال تا اپ قفل نکند
      }
    }
    return _localUpdateStatus(id, status,
        receiptPath: receiptPath, totalPrice: totalPrice);
  }

  /// لغو توسط خود مشتری: فقط وقتی مالک خودش باشد و سفارش هنوز
  /// در مرحله قابل‌لغو (pending/awaiting_payment) باشد.
  Future<String> cancelByUser(String id, String forUser) async {
    final o = await byId(id);
    if (o == null) return updateNotFound;
    if (o.owner.isNotEmpty && o.owner != forUser) return cancelForbidden;
    if (o.status != OrderStatuses.pending &&
        o.status != OrderStatuses.awaitingPayment) {
      return cancelNotAllowed;
    }
    return updateStatus(id, OrderStatuses.cancelled);
  }

  /// حذف کامل (فقط مدیر — صداکننده باید isAdmin را چک کرده باشد).
  /// برای جلوگیری از رشد بی‌نهایت حافظه لوکال و تمیزکاری سفارش‌های آزمایشی.
  Future<bool> deleteOrder(String id) async {
    var remoteOk = false;
    final client = SupabaseService.clientOrNull();
    if (client != null) {
      try {
        await client.from('orders').delete().eq('id', id);
        remoteOk = true;
      } catch (_) {
        remoteOk = false;
      }
    }
    final localOk = await _localDelete(id);
    // آفلاین: فقط لوکال مهم است. آنلاین: حداقل یکی باید موفق باشد.
    return client == null ? localOk : (remoteOk || localOk);
  }

  /// یک سفارش با شناسه (برای رفرش صفحه پرداخت بعد از اعلام مبلغ توسط مدیر).
  /// null یعنی سفارش حذف/پیدا نشد — صفحه پرداخت باید پیام مناسب نشان دهد نه کرش.
  Future<QandOrder?> byId(String id) async {
    final client = SupabaseService.clientOrNull();
    if (client != null) {
      try {
        final row = await client.from('orders').select().eq('id', id).maybeSingle();
        if (row != null) {
          return QandOrderMapper.fromMap(Map<String, dynamic>.from(row));
        }
      } catch (_) {
        // fallback لوکال
      }
    }
    return _localById(id);
  }

  // ---------------- حالت ریموت ----------------

  Future<List<QandOrder>?> _remoteAll(
      {String? forUser, bool isAdmin = false}) async {
    final client = SupabaseService.clientOrNull();
    if (client == null) return null;
    try {
      var q = client.from('orders').select().order('created_at', ascending: false);
      final rows = await q;
      final list = (rows as List<dynamic>)
          .map((e) => QandOrderMapper.fromMap(
              Map<String, dynamic>.from(e as Map<String, dynamic>)))
          .toList();
      if (isAdmin) return list;
      if (forUser == null) return <QandOrder>[];
      return list
          .where((o) => o.owner == forUser || o.owner.isEmpty && false)
          .toList();
    } catch (_) {
      return null; // fallback لوکال
    }
  }

  Future<QandOrder?> _remoteAdd(QandOrder o) async {
    final client = SupabaseService.clientOrNull();
    if (client == null) return null;
    try {
      final rows = await client
          .from('orders')
          .insert(QandOrderMapper.toMap(o))
          .select();
      final list = rows as List<dynamic>;
      if (list.isEmpty) return null;
      return QandOrderMapper.fromMap(
          Map<String, dynamic>.from(list.first as Map));
    } catch (_) {
      return null; // fallback لوکال (مثلاً RLS بسته یا آفلاین)
    }
  }

  // ---------------- حالت لوکال ----------------

  Future<List<QandOrder>> _localAll(
      {String? forUser, bool isAdmin = false}) async {
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

  Future<void> _localAdd(QandOrder o) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList(_k) ?? [];
    raw.add(_encode(o));
    await p.setStringList(_k, raw);
  }

  Future<void> _localUpsert(QandOrder o) async {
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
    final i = list.indexWhere((e) => e.id == o.id);
    if (i == -1) {
      list.add(o);
    } else {
      list[i] = o;
    }
    await p.setStringList(_k, list.map(_encode).toList());
  }

  Future<String> _localUpdateStatus(String id, String status,
      {String? receiptPath, int? totalPrice}) async {
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
    list[i] = list[i].copyWith(
        status: status, receiptPath: receiptPath, totalPrice: totalPrice);
    await p.setStringList(_k, list.map(_encode).toList());
    return updateOk;
  }

  Future<bool> _localDelete(String id) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList(_k) ?? [];
    final kept = <String>[];
    var removed = false;
    for (final s in raw) {
      try {
        final o = _decode(s);
        if (o.id == id) {
          removed = true;
          continue;
        }
        kept.add(s);
      } catch (_) {
        kept.add(s); // رکورد خراب را نگه دار تا داده گم نشود؟ نه — نادیده بگیر
      }
    }
    if (removed) await p.setStringList(_k, kept);
    return removed;
  }

  Future<QandOrder?> _localById(String id) async {
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
        'id': o.id,
        'productId': o.productId,
        'productTitle': o.productTitle,
        'qty': o.qty,
        'persons': o.persons,
        'fullName': o.fullName,
        'phone': o.phone,
        'address': o.address,
        'deliveryDate': o.deliveryDate,
        'note': o.note,
        'status': o.status,
        'totalPrice': o.totalPrice,
        'receiptPath': o.receiptPath,
        'createdAt': o.createdAt,
        'owner': o.owner,
        'trackingCode': o.trackingCode,
        'fulfillment': o.fulfillment,
        'deliveryFee': o.deliveryFee,
        'itemsSummary': o.itemsSummary,
        'cakeOptions': o.cakeOptions,
      });

  QandOrder _decode(String s) {
    final m = jsonDecode(s) as Map<String, dynamic>;
    final fulfillment = '${m['fulfillment'] ?? Fulfillment.delivery}';
    return QandOrder(
      id: '${m['id']}',
      productId: '${m['productId']}',
      productTitle: '${m['productTitle']}',
      qty: parseIntSafe(m['qty'], 1),
      persons: parseIntSafe(m['persons'], 1),
      fullName: '${m['fullName'] ?? ''}',
      phone: '${m['phone'] ?? ''}',
      address: '${m['address'] ?? ''}',
      deliveryDate: '${m['deliveryDate'] ?? ''}',
      note: '${m['note'] ?? ''}',
      status: '${m['status'] ?? OrderStatuses.pending}',
      totalPrice: parseIntSafe(m['totalPrice'], 0),
      receiptPath: m['receiptPath'] as String?,
      createdAt: '${m['createdAt'] ?? ''}',
      owner: '${m['owner'] ?? ''}',
      trackingCode: '${m['trackingCode'] ?? ''}',
      fulfillment:
          fulfillment == Fulfillment.pickup ? Fulfillment.pickup : Fulfillment.delivery,
      deliveryFee: parseIntSafe(m['deliveryFee'], 0),
      itemsSummary: '${m['itemsSummary'] ?? ''}',
      cakeOptions: '${m['cakeOptions'] ?? ''}',
    );
  }
}

/// نگاشت بین مدل اپ و جدول `orders` سوپابیس.
/// جدول ممکن است ستون‌های جدید (customer_username/product_title/tracking_code)
/// را نداشته باشد (سرور قدیمی) — پس insert را حداقلی می‌فرستیم و خواندن را
/// با fallback انجام می‌دهیم تا با هر دو نسخه کار کند.
class QandOrderMapper {
  static bool _isUuid(String s) => RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
      .hasMatch(s);

  static Map<String, dynamic> toMap(QandOrder o) {
    final m = <String, dynamic>{
      'qty': o.qty,
      'persons': o.persons,
      'full_name': o.fullName,
      'phone': o.phone,
      'address': o.address,
      'delivery_date': o.deliveryDate,
      'note': o.note,
      'status': o.status,
      'total_price': o.totalPrice,
      'customer_username': o.owner,
      'product_title': o.productTitle,
      'tracking_code': o.trackingCode,
      'fulfillment': o.fulfillment,
      'delivery_fee': o.deliveryFee,
      'items_summary': o.itemsSummary,
      'cake_options': o.cakeOptions,
    };
    if (o.receiptPath != null && o.receiptPath!.isNotEmpty) {
      m['receipt_url'] = o.receiptPath;
    }
    // فقط uuid معتبر را به‌عنوان کلید بفرست؛ idهای دموی قدیمی را DB می‌سازد.
    if (_isUuid(o.id)) m['id'] = o.id;
    if (_isUuid(o.productId)) m['product_id'] = o.productId;
    return m;
  }

  static QandOrder fromMap(Map<String, dynamic> m) {
    final fulfillment =
        '${m['fulfillment'] ?? Fulfillment.delivery}';
    return QandOrder(
      id: '${m['id'] ?? ''}',
      productId: '${m['product_id'] ?? ''}',
      productTitle: '${m['product_title'] ?? m['productTitle'] ?? ''}',
      qty: parseIntSafe(m['qty'], 1),
      persons: parseIntSafe(m['persons'], 1),
      fullName: '${m['full_name'] ?? m['fullName'] ?? ''}',
      phone: '${m['phone'] ?? ''}',
      address: '${m['address'] ?? ''}',
      deliveryDate: '${m['delivery_date'] ?? m['deliveryDate'] ?? ''}',
      note: '${m['note'] ?? ''}',
      status: '${m['status'] ?? OrderStatuses.pending}',
      totalPrice: parseIntSafe(m['total_price'] ?? m['totalPrice'], 0),
      receiptPath: (m['receipt_url'] ?? m['receiptPath']) as String?,
      createdAt: '${m['created_at'] ?? m['createdAt'] ?? ''}',
      owner: '${m['customer_username'] ?? m['owner'] ?? ''}',
      trackingCode: '${m['tracking_code'] ?? m['trackingCode'] ?? ''}',
      fulfillment: fulfillment == Fulfillment.pickup
          ? Fulfillment.pickup
          : Fulfillment.delivery,
      deliveryFee: parseIntSafe(m['delivery_fee'] ?? m['deliveryFee'], 0),
      itemsSummary: '${m['items_summary'] ?? m['itemsSummary'] ?? ''}',
      cakeOptions: '${m['cake_options'] ?? m['cakeOptions'] ?? ''}',
    );
  }
}
