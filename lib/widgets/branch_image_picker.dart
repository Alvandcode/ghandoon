import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/product_image_service.dart';
import '../theme/qand_theme.dart';

/// انتخاب عکس سفارشی شاخه از گالری (آپلود به Storage و برگرداندن URL).
/// خالی (null) یعنی آیکون پیش‌فرض ماتریال همان شاخه.
///
/// کنترل‌شده است: مقدار از [imageUrl] خوانده می‌شود (نه state داخلی)،
/// پس با حذف/افزودن ردیف‌ها مقدار هر ردیف قاطی نمی‌شود.
/// نگاشت با نام شاخه ذخیره می‌شود (نه ایندکس) تا حذف یک شاخه،
/// عکس بقیه را جابه‌جا نکند؛ حذف شاخه ورودی عکسش را هم می‌برد.
class BranchImagePicker extends StatefulWidget {
  final String? imageUrl;
  final IconData fallbackIcon;
  final ValueChanged<String?> onChanged;
  const BranchImagePicker({
    super.key,
    this.imageUrl,
    required this.fallbackIcon,
    required this.onChanged,
  });

  @override
  State<BranchImagePicker> createState() => _BranchImagePickerState();
}

class _BranchImagePickerState extends State<BranchImagePicker> {
  bool _uploading = false;

  String? get _url {
    final u = (widget.imageUrl ?? '').trim();
    return u.isEmpty ? null : u;
  }

  Future<void> _pickFromGallery() async {
    if (_uploading) return;
    try {
      final img = await ImagePicker()
          .pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (img == null || !mounted) return;
      setState(() => _uploading = true);
      final url = await ProductImageService().uploadProductImage(img.path);
      if (!mounted) return;
      if (url == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('آپلود ناموفق بود؛ آفلاین هستی یا دسترسی بسته است')));
        return;
      }
      widget.onChanged(url);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('انتخاب عکس ناموفق بود')));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = _url;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // پیش‌نمایش: عکس سفارشی یا آیکون پیش‌فرض
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: QandTheme.red, width: 2),
          ),
          child: ClipOval(
            child: url != null
                ? Image.network(url,
                    width: 46,
                    height: 46,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Icon(widget.fallbackIcon, color: QandTheme.red))
                : Icon(widget.fallbackIcon, color: QandTheme.red),
          ),
        ),
        const SizedBox(width: 2),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: _uploading ? null : _pickFromGallery,
              child: _uploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('عکس 🖼️',
                      style: TextStyle(fontSize: 11)),
            ),
            if (url != null)
              TextButton(
                onPressed: () => widget.onChanged(null),
                child: const Text('حذف',
                    style: TextStyle(fontSize: 11, color: Colors.red)),
              ),
          ],
        ),
      ],
    );
  }
}
