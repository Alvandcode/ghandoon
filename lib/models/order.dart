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
  });

  QandOrder copyWith({String? status, String? receiptPath, int? totalPrice}) {
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
    );
  }
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
