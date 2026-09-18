class QandOrder {
  final String id;
  final String productId;
  final String productTitle;
  final int qty;
  final int persons;
  final String fullName;
  final String phone;
  final String address;
  final String deliveryDate; // رشته شمسی مثلا 1405/06/20
  final String note;
  final String status;
  final int totalPrice;
  final String? receiptPath;
  final String createdAt;
  /// نام‌کاربری ثبت‌کننده سفارش (برای تفکیک سفارش هر کاربر).
  /// سفارش‌های قدیمی ممکن است خالی باشد ('') — برای سازگاری نگه داشته می‌شود.
  final String owner;
  /// کد پیگیری کوتاه انسانی مثل QND-8X42K1 — برای پیگیری تلفنی و چاپ فاکتور.
  /// سفارش‌های قدیمی ممکن است خالی باشد ('')؛ در این صورت UI از id کوتاه‌شده استفاده می‌کند.
  final String trackingCode;
  /// نحوه تحویل: 'pickup' (حضوری) یا 'delivery' (ارسال با پیک). قدیمی‌ها 'delivery'.
  final String fulfillment;
  /// هزینه پیک (تومان). حضوری = ۰. داخل totalPrice لحاظ شده است.
  final int deliveryFee;
  /// شرح اقلام برای سفارش‌های سبدی، مثل «کیک خونگی ×۲ + کوکی ×۱».
  /// سفارش تکی خالی می‌ماند و UI از productTitle استفاده می‌کند.
  final String itemsSummary;
  /// مشخصات کیک سفارشی (وزن/طعم/فیلینگ/متن روی کیک). خالی = ندارد.
  final String cakeOptions;

  const QandOrder({
    required this.id,
    required this.productId,
    required this.productTitle,
    required this.qty,
    required this.persons,
    required this.fullName,
    required this.phone,
    required this.address,
    required this.deliveryDate,
    required this.note,
    required this.status,
    required this.totalPrice,
    this.receiptPath,
    required this.createdAt,
    this.owner = '',
    this.trackingCode = '',
    this.fulfillment = Fulfillment.delivery,
    this.deliveryFee = 0,
    this.itemsSummary = '',
    this.cakeOptions = '',
  });

  QandOrder copyWith(
      {String? status,
      String? receiptPath,
      int? totalPrice,
      String? trackingCode,
      String? fulfillment,
      int? deliveryFee,
      String? itemsSummary,
      String? cakeOptions}) {
    return QandOrder(
      id: id,
      productId: productId,
      productTitle: productTitle,
      qty: qty,
      persons: persons,
      fullName: fullName,
      phone: phone,
      address: address,
      deliveryDate: deliveryDate,
      note: note,
      status: status ?? this.status,
      totalPrice: totalPrice ?? this.totalPrice,
      receiptPath: receiptPath ?? this.receiptPath,
      createdAt: createdAt,
      owner: owner,
      trackingCode: trackingCode ?? this.trackingCode,
      fulfillment: fulfillment ?? this.fulfillment,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      itemsSummary: itemsSummary ?? this.itemsSummary,
      cakeOptions: cakeOptions ?? this.cakeOptions,
    );
  }

  /// نمایشی برای کاربر: کد پیگیری اگر هست، وگرنه ۸ کاراکتر اول id.
  String get displayCode =>
      trackingCode.isNotEmpty ? trackingCode : (id.length <= 8 ? id : id.substring(0, 8));

  /// عنوان نمایشی اقلام: شرح سبد اگر هست، وگرنه «محصول ×تعداد».
  String get displayItems =>
      itemsSummary.isNotEmpty ? itemsSummary : '$productTitle × $qty';

  bool get isPickup => fulfillment == Fulfillment.pickup;
}

/// نحوه تحویل سفارش.
class Fulfillment {
  static const pickup = 'pickup'; // تحویل حضوری
  static const delivery = 'delivery'; // ارسال با پیک

  static String fa(String v) => v == pickup ? 'حضوری' : 'ارسال با پیک';
}

class OrderStatuses {
  static const pending = 'pending'; // ثبت‌شده
  static const awaitingPayment = 'awaiting_payment'; // در انتظار پرداخت
  static const receiptSent = 'receipt_sent'; // فیش ارسال شد
  static const approved = 'approved'; // تایید شده
  static const ready = 'ready'; // آماده تحویل
  static const delivered = 'delivered';
  static const cancelled = 'cancelled';

  static String fa(String s) {
    switch (s) {
      case pending:
        return 'ثبت‌شده، در انتظار بررسی مدیر';
      case awaitingPayment:
        return 'در انتظار پرداخت';
      case receiptSent:
        return 'فیش ارسال شد، در انتظار تایید';
      case approved:
        return 'تایید شد';
      case ready:
        return 'آماده تحویل';
      case delivered:
        return 'تحویل شد';
      case cancelled:
        return 'لغو شد';
      default:
        return s;
    }
  }

  static const List<String> flow = [
    pending,
    awaitingPayment,
    receiptSent,
    approved,
    ready,
    delivered,
  ];
}
