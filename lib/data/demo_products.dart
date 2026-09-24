import '../models/product.dart';

// دیتای پیش‌فرض تا وقتی مدیر از پنل محصول اضافه کند.
// دسته‌ها با چهار شاخه اصلی پیش‌فرض (AppConfig.defaultMainCategories) یکی‌اند.

const List<Product> demoProducts = [
  Product(
    id: 'homemade',
    title: 'کیک خونگی',
    category: 'کیک',
    description: 'کیک خونگی تازه با دستور مادربزرگ، بافت نرم و عطر وانیل. مناسب دورهمی و عصرانه.',
    ingredients: 'آرد، تخم‌مرغ، شکر، کره، شیر، وانیل، بیکینگ‌پودر',
    price: 280000,
    unit: 'عدد (1 کیلویی)',
    asset: 'assets/images/cupcake.png',
  ),
  Product(
    id: 'cookie',
    title: 'کوکی کشمشی',
    category: 'شیرینی',
    description: 'کوکی ترد با کشمش و گردو، پخت روزانه. مناسب پذیرایی و هدیه.',
    ingredients: 'آرد، کره، شکر قهوه‌ای، کشمش، گردو، تخم‌مرغ، دارچین',
    price: 180000,
    unit: 'بسته نیم‌کیلویی',
    asset: 'assets/images/cookies.png',
  ),
  Product(
    id: 'biscuit',
    title: 'رولت خامه‌ای',
    category: 'شیرینی',
    description: 'رولت اسفنجی سبک با خامه وانیلی و روکش شکلات. انتخاب بچه‌ها.',
    ingredients: 'آرد، تخم‌مرغ، شکر، خامه، وانیل، شکلات',
    price: 220000,
    unit: 'عدد',
    asset: 'assets/images/roll.png',
  ),
  Product(
    id: 'birthday',
    title: 'کیک تولد اختصاصی',
    category: 'کیک',
    description: 'کیک تولد چندطبقه با دیزاین دلخواه، گل طبیعی و تاپر. عکس نمونه‌ات را هم می‌توانی بفرستی.',
    ingredients: 'کیک شکلاتی/وانیلی، خامه، میوه فصل، فوندانت (سفارشی)',
    price: 650000,
    unit: 'پایه (2 کیلویی)',
    asset: 'assets/images/birthday.png',
  ),
];

/// سازگاری با کد قدیمی — همان چهار شاخه اصلی.
const List<String> categories = ['دسر', 'شیرینی', 'کیک', 'شکلات'];
