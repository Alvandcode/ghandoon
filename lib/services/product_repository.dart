import '../data/demo_products.dart';
import '../models/product.dart';
import 'supabase_service.dart';

/// نتیجه‌ی بارگذاری محصولات.
/// - [products]: لیست محصولات (در حالت آفلاین = دمو)
/// - [source]: از کجا آمده — تا UI بتواند حالت «فروشگاه واقعا خالی» را
///   از «آفلاین/خطا» تشخیص دهد و با هم قاطی نشوند.
class ProductLoadResult {
  final List<Product> products;
  final ProductSource source;
  const ProductLoadResult(this.products, this.source);
}

enum ProductSource { demoOffline, supabase, supabaseEmpty }

/// مخزن محصولات:
/// - آفلاین (سوپابیس پیکربندی نشده): دمو نمایش داده می‌شود.
/// - سوپابیس وصل: لیست فعال از جدول `products`.
///   * جدول خالی = حالت صریح [ProductSource.supabaseEmpty] برمی‌گردد
///     (قبلاً «خالی» با دمو قاطی می‌شد و فروشنده فکر می‌کرد محصولاتش حذف شده‌اند).
///   * خطای شبکه: fallback دمو + علت، تا اپ هیچ‌وقت صفحه خالی/کرش نشان ندهد.
class ProductRepository {
  Future<ProductLoadResult> loadActiveWithSource() async {
    final client = SupabaseService.clientOrNull();
    if (client == null) {
      return const ProductLoadResult(demoProducts, ProductSource.demoOffline);
    }
    try {
      final rows = await client
          .from('products')
          .select()
          .eq('is_active', true)
          .order('created_at', ascending: true);
      final list = (rows as List<dynamic>)
          .map((e) => Product.fromMap(Map<String, dynamic>.from(e as Map<String, dynamic>)))
          .where((p) => p.title.isNotEmpty)
          .toList();
      if (list.isEmpty) {
        return const ProductLoadResult([], ProductSource.supabaseEmpty);
      }
      return ProductLoadResult(list, ProductSource.supabase);
    } catch (_) {
      // خطای شبکه = دمو + علت (آفلاین)، نه «فروشگاه خالی»
      return const ProductLoadResult(demoProducts, ProductSource.demoOffline);
    }
  }

  /// سازگاری با کد قبلی: فقط لیست.
  /// اگر سوپابیس وصل باشد و جدول خالی/خطا باشد، دمو برنمی‌گردد (لیست خالی می‌دهد)
  /// تا UI بتواند پیام درست نشان دهد.
  Future<List<Product>> loadActive() async {
    final r = await loadActiveWithSource();
    if (r.source == ProductSource.demoOffline) return r.products;
    if (r.source == ProductSource.supabaseEmpty) return const [];
    return r.products;
  }

  /// فعال/غیرفعال کردن محصول (فقط وقتی سوپابیس وصل است؛ آفلاین false).
  /// مدیر فروشگاه با این دکمه محصول ناموجود را بدون حذف مخفی می‌کند.
  Future<bool> setActive(String id, bool active) async {
    final client = SupabaseService.clientOrNull();
    if (client == null) return false;
    try {
      await client.from('products').update({'is_active': active}).eq('id', id);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// ویرایش قیمت (تومان). نامعتبر (<=0) بدون تماس با سرور false می‌دهد.
  Future<bool> updatePrice(String id, int price) async {
    if (price <= 0) return false;
    final client = SupabaseService.clientOrNull();
    if (client == null) return false;
    try {
      await client.from('products').update({'price': price}).eq('id', id);
      return true;
    } catch (_) {
      return false;
    }
  }
}
