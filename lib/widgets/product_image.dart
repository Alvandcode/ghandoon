import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// نمایش عکس محصول:
/// - اگر imageUrl (سوپابیس) موجود باشد از کش شبکه استفاده می‌کند.
/// - وگرنه عکس لوکال asset را نشان می‌دهد.
/// - اگر هیچ‌کدام لود نشد، ایموجی fallback (بدون کرش).
class ProductImage extends StatelessWidget {
  final String asset;
  final String? imageUrl;
  final double? height;
  final double? width;
  final BoxFit fit;
  final double iconSize;

  const ProductImage({
    super.key,
    required this.asset,
    this.imageUrl,
    this.height,
    this.width,
    this.fit = BoxFit.cover,
    this.iconSize = 48,
  });

  @override
  Widget build(BuildContext context) {
    final url = (imageUrl ?? '').trim();
    if (url.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: url,
        height: height,
        width: width,
        fit: fit,
        placeholder: (_, __) => _asset(fallbackLoading: true),
        errorWidget: (_, __, ___) => _asset(),
      );
    }
    return _asset();
  }

  Widget _asset({bool fallbackLoading = false}) {
    return Image.asset(
      asset,
      height: height,
      width: width,
      fit: fit,
      errorBuilder: (_, __, ___) => SizedBox(
        height: height ?? 120,
        width: width ?? double.infinity,
        child: Center(
          child: fallbackLoading
              ? const CircularProgressIndicator()
              : Text('🧁', style: TextStyle(fontSize: iconSize)),
        ),
      ),
    );
  }
}
