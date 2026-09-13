import '../data/demo_products.dart';
import '../models/product.dart';
import 'supabase_service.dart';

/// مخزن محصولات:
/// - اگر سوپابیس وصل باشد، لیست فعال از جدول `products` خوانده می‌شود.
/// - در هر خطایی (آفلاین، جدول خالی، اینترنت قطع) به `demoProducts` برمی‌گردد
///   تا اپ هیچ‌وقت صفحه خالی/کرش نشان ندهد.
///
/// چرا سفارش‌ها اینجا نیست؟ چون احراز هویت هنوز لوکال است و نگاشت
/// owner متنی به user_id (uuid) نیاز به مهاجرت به Supabase Auth دارد؛
/// تا آن موقع سفارش‌ها عمدا لوکال می‌مانند (امن‌تر از مپ اشتباه).
class ProductRepository {
  Future<List<Product>> loadActive() async {
    final client = SupabaseService.clientOrNull();
    if (client == null) return demoProducts;
    try {
      final rows = await client
          .from('products')
          .select()
          .eq('is_active', true)
          .order('created_at', ascending: true);
      final list = (rows as List)
          .map((e) => Product.fromMap(Map<String, dynamic>.from(e as Map)))
          .where((p) => p.title.isNotEmpty)
          .toList();
      // جدول خالی = احتمالا سید اجرا نشده؛ دمو را نشان بده تا فروشنده گیج نشود
      if (list.isEmpty) return demoProducts;
      return list;
    } catch (_) {
      return demoProducts;
    }
  }
}
