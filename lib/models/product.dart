import '../utils/format.dart';

class Product {
  final String id;
  final String title;
  final String category; // کیک خونگی | کوکی | بیسکوییت | کیک تولد
  final String description;
  final String ingredients;
  final int price; // تومان
  final String unit;
  final String asset; // مسیر عکس لوکال
  final String? imageUrl; // عکس اصلی از سوپابیس (لیست و کارت)
  /// عکس صفحه توضیحات (بنر بزرگ). خالی = همان عکس اصلی نشان داده می‌شود.
  final String? detailImageUrl;
  /// فعال بودن برای فروش. دموها همیشه true؛ از سرور می‌آید.
  final bool isActive;

  const Product({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.ingredients,
    required this.price,
    required this.unit,
    required this.asset,
    this.imageUrl,
    this.detailImageUrl,
    this.isActive = true,
  });

  Product copyWith({int? price, bool? isActive, String? imageUrl, String? detailImageUrl}) {
    return Product(
      id: id,
      title: title,
      category: category,
      description: description,
      ingredients: ingredients,
      price: price ?? this.price,
      unit: unit,
      asset: asset,
      imageUrl: imageUrl ?? this.imageUrl,
      detailImageUrl: detailImageUrl ?? this.detailImageUrl,
      isActive: isActive ?? this.isActive,
    );
  }

  factory Product.fromMap(Map<String, dynamic> m) {
    final category = '${m['category'] ?? ''}';
    final active = m['is_active'];
    return Product(
      id: '${m['id'] ?? ''}',
      title: '${m['title'] ?? ''}',
      category: category,
      description: '${m['description'] ?? ''}',
      ingredients: '${m['ingredients'] ?? ''}',
      price: parseIntSafe(m['price'], 0),
      unit: '${m['unit'] ?? 'عدد'}',
      asset: _assetForCategory(category),
      imageUrl: m['image_url'] as String?,
      detailImageUrl: m['detail_image_url'] as String?,
      isActive: active == null ? true : active == true || '$active' == 'true' || '$active' == '1',
    );
  }

  /// عکس پیش‌فرض هر دسته (همه این فایل‌ها واقعا در assets/images وجود دارند).
  static String _assetForCategory(String category) {
    switch (category) {
      case 'کیک خونگی':
        return 'assets/images/cupcake.png';
      case 'کوکی':
        return 'assets/images/cookies.png';
      case 'بیسکوییت':
        return 'assets/images/roll.png';
      case 'کیک تولد':
        return 'assets/images/birthday.png';
      default:
        return 'assets/images/cake_slice.png';
    }
  }
}
