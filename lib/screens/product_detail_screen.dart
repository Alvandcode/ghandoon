import 'package:flutter/material.dart';
import '../theme/qand_theme.dart';
import '../models/product.dart';
import '../utils/format.dart';
import '../widgets/product_image.dart';
import 'order_form_screen.dart';
import 'chat_screen.dart';

class ProductDetailScreen extends StatelessWidget {
  final Product product;
  final String username;
  const ProductDetailScreen({super.key, required this.product, required this.username});

  String _toman(int v) => formatToman(v);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(children: [
          Container(
            decoration: QandTheme.headerGradient(),
            padding: const EdgeInsets.fromLTRB(16, 48, 16, 24),
            child: Column(children: [
              Row(children: [
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_forward, color: Colors.white)),
                const Spacer(),
                Text(product.category, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: ProductImage(
                  asset: product.asset,
                  imageUrl: product.imageUrl,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  iconSize: 80,
                ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(product.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: QandTheme.cream, borderRadius: BorderRadius.circular(14)),
                  child: Text(_toman(product.price), style: const TextStyle(fontWeight: FontWeight.bold, color: QandTheme.red))),
              ]),
              Text(product.unit, style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 12),
              _box('توضیحات', product.description, Icons.description_outlined),
              _box('مواد تشکیل‌دهنده', product.ingredients, Icons.egg_outlined),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderFormScreen(product: product, username: username))),
                child: const Text('لینک سفارش → ثبت سفارش'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatScreen())),
                icon: const Icon(Icons.support_agent),
                label: const Text('ارتباط با مدیر'),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _box(String t, String d, IconData ic) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(ic, color: QandTheme.red),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(d, style: const TextStyle(height: 1.8)),
          ])),
        ]),
      ),
    );
  }
}
