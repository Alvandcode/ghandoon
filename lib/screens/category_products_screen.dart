import 'package:flutter/material.dart';
import '../theme/qand_theme.dart';
import '../models/product.dart';
import '../services/cart_service.dart';
import '../services/product_repository.dart';
import '../utils/format.dart';
import '../utils/product_validate.dart';
import '../widgets/gradient_app_bar.dart';
import '../widgets/product_image.dart';
import '../widgets/safe_scaffold.dart';
import 'cart_screen.dart';
import 'product_detail_screen.dart';

/// لیست محصولات (زیرشاخه‌های) یک شاخه اصلی سفارش.
/// مسیر فلو: خانه ← انتخاب دسته ← این صفحه ← جزئیات/سفارش.
class CategoryProductsScreen extends StatefulWidget {
  final String category;
  final String username;
  const CategoryProductsScreen({
    super.key,
    required this.category,
    required this.username,
  });
  @override
  State<CategoryProductsScreen> createState() => _CategoryProductsScreenState();
}

class _CategoryProductsScreenState extends State<CategoryProductsScreen> {
  List<Product> _all = [];
  bool _loading = true;
  bool _supabaseEmpty = false;
  int _cartCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
    _refreshCartCount();
  }

  Future<void> _load() async {
    final r = await ProductRepository().loadActiveWithSource();
    if (!mounted) return;
    setState(() {
      _all = r.products;
      _supabaseEmpty = r.source == ProductSource.supabaseEmpty;
      _loading = false;
    });
  }

  Future<void> _refreshCartCount() async {
    final n = await CartService().count(widget.username);
    if (!mounted) return;
    setState(() => _cartCount = n);
  }

  Future<void> _openCart() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CartScreen(username: widget.username)),
    );
    _refreshCartCount();
  }

  List<Product> get _items => _all
      .where((p) => productInMainCategory(p.category, widget.category))
      .toList();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final crossAxis = width < 360 ? 2 : (width > 600 ? 3 : 2);
    return Scaffold(
      appBar: GradientAppBar.of(
        context,
        title: widget.category,
        actions: [
          IconButton(
            tooltip: 'سبد خرید',
            onPressed: _openCart,
            icon: Badge(
              isLabelVisible: _cartCount > 0,
              label: Text('$_cartCount'),
              child: const Icon(Icons.shopping_cart_outlined,
                  color: Colors.white),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? Center(
                  child: Padding(
                    padding: bottomSafePadding(context, base: 24),
                    child: Text(
                      _supabaseEmpty
                          ? 'فعلاً محصولی برای فروش فعال نیست 🛒'
                          : 'هنوز محصولی توی «${widget.category}» نیست.\nمدیر به‌زودی اضافه می‌کند 🍰',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 15),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: GridView.builder(
                    padding: bottomSafePadding(context, base: 14),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxis,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: crossAxis == 3 ? 0.78 : 0.72,
                    ),
                    itemCount: _items.length,
                    itemBuilder: (_, i) => _productCard(_items[i]),
                  ),
                ),
    );
  }

  Widget _productCard(Product p) {
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  ProductDetailScreen(product: p, username: widget.username),
            ),
          );
          _refreshCartCount();
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ProductImage(
                asset: p.asset,
                imageUrl: p.imageUrl,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                iconSize: 48,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    p.unit,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: QandTheme.cream,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      formatToman(p.price),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: QandTheme.red),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
