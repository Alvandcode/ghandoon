import 'dart:io';
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

/// آپلود عکس محصول در باکت `product-images`.
/// - آنلاین: فایل با اسم یکتا آپلود و لینک عمومی برمی‌گردد.
/// - آفلاین/خطا: null برمی‌گردد (UI باید پیام بدهد، نه کرش).
/// هرگز throw نمی‌کند.
class ProductImageService {
  static const bucket = 'product-images';

  Future<String?> uploadProductImage(String localPath) async {
    final client = SupabaseService.clientOrNull();
    if (client == null) return null;
    try {
      final file = File(localPath);
      if (!await file.exists()) return null;
      final ext = _ext(localPath);
      final name =
          '${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(1 << 32)}$ext';
      final objectPath = 'products/$name';
      await client.storage.from(bucket).upload(
            objectPath,
            file,
            fileOptions: const FileOptions(
                upsert: false, contentType: 'image/jpeg'),
          );
      final url = client.storage.from(bucket).getPublicUrl(objectPath);
      return url.isEmpty ? null : url;
    } catch (_) {
      return null;
    }
  }

  String _ext(String path) {
    final p = path.replaceAll('\\', '/');
    final dot = p.lastIndexOf('.');
    final slash = p.lastIndexOf('/');
    if (dot < 0 || dot < slash) return '.jpg';
    final e = p.substring(dot).toLowerCase();
    return ['.jpg', '.jpeg', '.png', '.webp'].contains(e) ? e : '.jpg';
  }
}
