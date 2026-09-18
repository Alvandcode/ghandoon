import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

/// آپلود فیش واریزی:
/// - اگر سوپابیس وصل باشد → فایل در باکت `receipts` با مسیر
///   `username/orderId/basename` آپلود و URL عمومی برگردانده می‌شود
///   (تا مدیر روی گوشی خودش فیش را ببیند — مشکل قبلی که فقط مسیر
///   لوکال `/data/...` ذخیره می‌شد).
/// - وگرنه یا در خطا → همان مسیر لوکال برمی‌گردد تا سفارش قفل نکند.
/// هرگز throw نمی‌کند.
class ReceiptService {
  static const bucket = 'receipts';

  Future<String> uploadReceipt({
    required String localPath,
    required String orderId,
    required String username,
  }) async {
    final client = SupabaseService.clientOrNull();
    if (client == null) return localPath;
    try {
      final file = File(localPath);
      if (!await file.exists()) return localPath;
      final base = _baseName(localPath);
      final safeUser =
          username.trim().isEmpty ? 'guest' : username.trim().replaceAll(RegExp(r'[^\w\-@.]+'), '_');
      final safeOrder = orderId.replaceAll(RegExp(r'[^\w\-]+'), '_');
      final objectPath = '$safeUser/$safeOrder/$base';
      await client.storage.from(bucket).upload(
            objectPath,
            file,
            fileOptions: const FileOptions(upsert: true),
          );
      // باکت receipts خصوصی است؛ ولی تا فعال‌شدن Auth و signed-url،
      // publicUrl بهترین چیزی است که مدیر می‌تواند ببیند.
      // اگر باکت private باشد، مدیر باید از داشبورد Storage ببیند.
      final url = client.storage.from(bucket).getPublicUrl(objectPath);
      return url.isNotEmpty ? url : localPath;
    } catch (_) {
      return localPath;
    }
  }

  String _baseName(String path) {
    final p = path.replaceAll('\\', '/');
    final i = p.lastIndexOf('/');
    var name = i >= 0 ? p.substring(i + 1) : p;
    name = name.replaceAll(RegExp(r'[^\w\-.]+'), '_');
    if (name.isEmpty) name = 'receipt.jpg';
    return name;
  }
}
