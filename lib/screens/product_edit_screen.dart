import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/product.dart';
import '../services/product_image_service.dart';
import '../services/product_repository.dart';
import '../services/settings_service.dart';
import '../services/supabase_service.dart';
import '../utils/format.dart';
import '../utils/product_validate.dart';
import '../widgets/gradient_app_bar.dart';
import '../widgets/product_image.dart';
import '../widgets/safe_scaffold.dart';

/// ویرایشگر محصول مدیر: هم «افزودن» (product == null) هم «ویرایش کامل».
/// عکس از گالری انتخاب و در Storage آپلود می‌شود؛ true برمی‌گرداند اگر
/// چیزی ذخیره شد تا لیست مدیر رفرش شود.
class ProductEditScreen extends StatefulWidget {
  final Product? product;
  const ProductEditScreen({super.key, this.product});
  @override
  State<ProductEditScreen> createState() => _ProductEditScreenState();
}

class _ProductEditScreenState extends State<ProductEditScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _price;
  late final TextEditingController _unit;
  late final TextEditingController _desc;
  late final TextEditingController _ingr;
  late String _category;
  late bool _active;
  /// چهار شاخه اصلی از تنظیمات (پیش‌فرض = AppConfig).
  List<String> _mainCategories = List.of(productCategories);
  String? _pickedPath; // عکس اصلی جدید (هنوز آپلود نشده)
  String? _pickedDetailPath; // عکس صفحه توضیحات جدید (هنوز آپلود نشده)
  bool _busy = false;
  String _busyMsg = '';

  bool get _isEdit => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _title = TextEditingController(text: p?.title ?? '');
    _price = TextEditingController(text: p == null ? '' : '${p.price}');
    _unit = TextEditingController(text: p?.unit ?? 'عدد');
    _desc = TextEditingController(text: p?.description ?? '');
    _ingr = TextEditingController(text: p?.ingredients ?? '');
    _category = (p != null && productCategories.contains(p.category))
        ? p.category
        : productCategories.first;
    _active = p?.isActive ?? true;
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final cats = await SettingsService().loadMainCategories();
    if (!mounted) return;
    setState(() {
      _mainCategories = cats;
      final p = widget.product;
      if (p != null) {
        final normalized =
            normalizeProductCategory(p.category, cats);
        _category =
            cats.contains(normalized) ? normalized : (cats.isNotEmpty ? cats.first : _category);
      } else if (!cats.contains(_category) && cats.isNotEmpty) {
        _category = cats.first;
      }
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _price.dispose();
    _unit.dispose();
    _desc.dispose();
    _ingr.dispose();
    super.dispose();
  }

  Future<void> _pickImage({bool detail = false}) async {
    try {
      final img = await ImagePicker()
          .pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (img == null || !mounted) return;
      setState(() {
        if (detail) {
          _pickedDetailPath = img.path;
        } else {
          _pickedPath = img.path;
        }
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('انتخاب عکس ناموفق بود؛ دسترسی گالری را بررسی کن')));
    }
  }

  Future<void> _save() async {
    if (_busy) return;
    if (!SupabaseService.isReady) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('آفلاین هستی؛ برای تغییر محصول اتصال سوپابیس لازم است')));
      return;
    }
    if (!_form.currentState!.validate()) return;
    final err = validateProductFields(
      title: _title.text,
      priceText: _price.text,
      category: _category,
      allowedCategories: _mainCategories,
    );
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    final price = parsePrice(_price.text)!;
    final hasNewImage = _pickedPath != null || _pickedDetailPath != null;
    setState(() {
      _busy = true;
      _busyMsg = hasNewImage ? 'در حال آپلود عکس...' : 'در حال ذخیره...';
    });
    try {
      String? imageUrl;
      String? detailImageUrl;
      if (_pickedPath != null) {
        setState(() => _busyMsg = 'در حال آپلود عکس اصلی...');
        imageUrl =
            await ProductImageService().uploadProductImage(_pickedPath!);
        if (imageUrl == null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('آپلود عکس ناموفق بود؛ دوباره تلاش کن')));
          return;
        }
      }
      if (_pickedDetailPath != null) {
        if (!mounted) return;
        setState(() => _busyMsg = 'در حال آپلود عکس صفحه توضیحات...');
        detailImageUrl = await ProductImageService()
            .uploadProductImage(_pickedDetailPath!);
        if (detailImageUrl == null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('آپلود عکس ناموفق بود؛ دوباره تلاش کن')));
          return;
        }
      }
      if (!mounted) return;
      setState(() => _busyMsg = 'در حال ذخیره...');
      final repo = ProductRepository();
      final saved = _isEdit
          ? await repo.updateProduct(
              widget.product!.id,
              title: _title.text,
              category: _category,
              price: price,
              unit: _unit.text,
              description: _desc.text,
              ingredients: _ingr.text,
              imageUrl: imageUrl, // null یعنی عکس قبلی بماند
              detailImageUrl: detailImageUrl,
              isActive: _active,
              allowedCategories: _mainCategories,
            )
          : await repo.createProduct(
              title: _title.text,
              category: _category,
              price: price,
              unit: _unit.text,
              description: _desc.text,
              ingredients: _ingr.text,
              imageUrl: imageUrl ?? '',
              detailImageUrl: detailImageUrl ?? '',
              isActive: _active,
              allowedCategories: _mainCategories,
            );
      if (!mounted) return;
      if (saved == null) {
        final why = repo.lastWriteError;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(why == null
                ? 'ذخیره ناموفق بود؛ اتصال را بررسی کن'
                : 'ذخیره ناموفق: $why')));
        return;
      }
      Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GradientAppBar.of(
        context,
        title: _isEdit ? 'ویرایش محصول ✏️' : 'محصول جدید ➕',
        onBack: _busy ? null : () => Navigator.pop(context),
      ),
      body: Form(
        key: _form,
        child: ListView(padding: bottomSafePadding(context), children: [
          _imagePicker(),
          const SizedBox(height: 12),
          _detailImagePicker(),
          const SizedBox(height: 12),
          TextFormField(
            controller: _title,
            maxLength: 60,
            decoration: const InputDecoration(
                labelText: 'اسم محصول *', prefixIcon: Icon(Icons.cake),
                counterText: ''),
            validator: (v) =>
                (v ?? '').trim().length < 2 ? 'اسم محصول حداقل ۲ حرف باشد' : null,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(
                labelText: 'دسته *', prefixIcon: Icon(Icons.category_outlined)),
            items: [
              for (final c in _mainCategories)
                DropdownMenuItem(value: c, child: Text(c)),
            ],
            onChanged: (v) => setState(() => _category = v ?? _category),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _price,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                labelText: 'قیمت (تومان) *', prefixIcon: Icon(Icons.payments_outlined),
                hintText: 'مثلا 450000'),
            validator: (v) =>
                parsePrice(v ?? '') == null ? 'قیمت معتبر نیست' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _unit,
            maxLength: 30,
            decoration: const InputDecoration(
                labelText: 'واحد', prefixIcon: Icon(Icons.scale_outlined),
                hintText: 'عدد', counterText: ''),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _desc,
            maxLines: 2,
            maxLength: 500,
            decoration: const InputDecoration(
                labelText: 'توضیحات', prefixIcon: Icon(Icons.description_outlined),
                counterText: ''),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _ingr,
            maxLines: 2,
            maxLength: 500,
            decoration: const InputDecoration(
                labelText: 'مواد تشکیل‌دهنده', prefixIcon: Icon(Icons.egg_outlined),
                counterText: ''),
          ),
          SwitchListTile(
            title: const Text('فعال برای فروش'),
            subtitle: const Text('خاموش = مشتری نمی‌بیند ولی حذف نمی‌شود'),
            value: _active,
            onChanged: (v) => setState(() => _active = v),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _busy ? null : _save,
            child: _busy
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white)),
                      const SizedBox(width: 10),
                      Text(_busyMsg),
                    ],
                  )
                : Text(_isEdit ? 'ذخیره تغییرات' : 'افزودن محصول'),
          ),
        ]),
      ),
    );
  }

  Widget _imagePicker() {
    return _imageSection(
      title: 'عکس اصلی (لیست و کارت)',
      pickedPath: _pickedPath,
      currentUrl: widget.product?.imageUrl,
      emptyHint: '📷 هنوز عکسی انتخاب نشده',
      pickLabelNull: 'انتخاب عکس (اختیاری)',
      onPick: () => _pickImage(),
    );
  }

  Widget _detailImagePicker() {
    return _imageSection(
      title: 'عکس صفحه توضیحات (اختیاری — خالی = همان عکس اصلی)',
      pickedPath: _pickedDetailPath,
      currentUrl: widget.product?.detailImageUrl,
      emptyHint: '📷 خالی = همان عکس اصلی نشان داده می‌شود',
      pickLabelNull: 'انتخاب عکس توضیحات (اختیاری)',
      onPick: () => _pickImage(detail: true),
    );
  }

  Widget _imageSection({
    required String title,
    required String? pickedPath,
    required String? currentUrl,
    required String emptyHint,
    required String pickLabelNull,
    required VoidCallback onPick,
  }) {
    Widget preview;
    if (pickedPath != null) {
      preview = Image.file(
        File(pickedPath),
        height: 180,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            const SizedBox(height: 180, child: Center(child: Text('🧁', style: TextStyle(fontSize: 64)))),
      );
    } else if (_isEdit) {
      // در حالت ویرایش همیشه چیزی برای نمایش هست (عکس سرور یا عکس پیش‌فرض دسته)
      final p = widget.product!;
      preview = ProductImage(
        asset: p.asset,
        imageUrl: currentUrl,
        height: 180,
        width: double.infinity,
        fit: BoxFit.cover,
        iconSize: 64,
      );
    } else {
      preview = Container(
        height: 140,
        width: double.infinity,
        decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(16)),
        child: Center(
            child: Text(emptyHint,
                style: const TextStyle(color: Colors.grey))),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        ClipRRect(borderRadius: BorderRadius.circular(16), child: preview),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _busy ? null : onPick,
          icon: const Icon(Icons.photo_library_outlined),
          label: Text(pickedPath == null && !_isEdit
              ? pickLabelNull
              : 'تغییر عکس'),
        ),
      ],
    );
  }
}
