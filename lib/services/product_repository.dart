import '../data/demo_products.dart';
import '../models/product.dart';
import '../utils/product_validate.dart';
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

  /// تغییر نام دسته روی همه محصولات آن دسته (سرور + آینه لوکال دمو).
  /// وقتی مدیر عنوان شاخه اصلی را عوض می‌کند، محصولات نباید یتیم شوند.
  Future<void> renameCategoryEverywhere(String oldName, String newName) async {
    final o = oldName.trim();
    final n = newName.trim();
    if (o.isEmpty || n.isEmpty || o == n) return;
    final client = SupabaseService.clientOrNull();
    if (client != null) {
      try {
        await client
            .from('products')
            .update({'category': n}).eq('category', o);
      } catch (_) {
        // خطای شبکه/RLS — ادامه با بقیه
      }
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

  /// ساخت محصول جدید (فقط آنلاین؛ آفلاین null).
  /// نامعتبر بودن ورودی قبل از تماس با سرور چک می‌شود.
  /// [allowedCategories] چهار شاخه اصلی تنظیمات مدیر (خالی = پیش‌فرض).
  Future<Product?> createProduct({
    required String title,
    required String category,
    required int price,
    required String unit,
    String description = '',
    String ingredients = '',
    String? imageUrl,
    String? detailImageUrl,
    bool isActive = true,
    List<String> allowedCategories = productCategories,
  }) async {
    if (validateProductFields(
            title: title,
            priceText: '$price',
            category: category,
            allowedCategories: allowedCategories) !=
        null) {
      return null;
    }
    final client = SupabaseService.clientOrNull();
    if (client == null) return null;
    try {
      final rows = await client.from('products').insert({
        'title': title.trim(),
        'category': category,
        'price': price,
        'unit': unit.trim().isEmpty ? 'عدد' : unit.trim(),
        'description': description.trim(),
        'ingredients': ingredients.trim(),
        'image_url': (imageUrl ?? '').trim().isEmpty ? null : imageUrl!.trim(),
        'detail_image_url': (detailImageUrl ?? '').trim().isEmpty
            ? null
            : detailImageUrl!.trim(),
        'is_active': isActive,
      }).select();
      final list = rows as List<dynamic>;
      if (list.isEmpty) return null;
      return Product.fromMap(Map<String, dynamic>.from(list.first as Map));
    } catch (_) {
      return null;
    }
  }

  /// ویرایش کامل محصول (فقط آنلاین؛ آفلاین null).
  /// اگر [imageUrl] داده نشود، عکس قبلی دست‌نخورده می‌ماند.
  Future<Product?> updateProduct(
    String id, {
    required String title,
    required String category,
    required int price,
    required String unit,
    String description = '',
    String ingredients = '',
    String? imageUrl,
    String? detailImageUrl,
    bool? isActive,
    List<String> allowedCategories = productCategories,
  }) async {
    if (validateProductFields(
            title: title,
            priceText: '$price',
            category: category,
            allowedCategories: allowedCategories) !=
        null) {
      return null;
    }
    final client = SupabaseService.clientOrNull();
    if (client == null) return null;
    try {
      final patch = <String, dynamic>{
        'title': title.trim(),
        'category': category,
        'price': price,
        'unit': unit.trim().isEmpty ? 'عدد' : unit.trim(),
        'description': description.trim(),
        'ingredients': ingredients.trim(),
      };
      if (imageUrl != null) {
        patch['image_url'] =
            imageUrl.trim().isEmpty ? null : imageUrl.trim();
      }
      if (detailImageUrl != null) {
        patch['detail_image_url'] =
            detailImageUrl.trim().isEmpty ? null : detailImageUrl.trim();
      }
      if (isActive != null) patch['is_active'] = isActive;
      final rows =
          await client.from('products').update(patch).eq('id', id).select();
      final list = rows as List<dynamic>;
      if (list.isEmpty) return null;
      return Product.fromMap(Map<String, dynamic>.from(list.first as Map));
    } catch (_) {
      return null;
    }
  }
}
