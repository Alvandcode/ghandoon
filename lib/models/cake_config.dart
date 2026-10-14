// ساختار قابل‌ویرایش «کیک تولد سفارشی».
//
// هدف: مدیر بتواند کل صفحه کیک‌ساز را بدون تغییر کد بچیند —
// بخش جدید اضافه کند (مثل «مغزیجات»)، گزینه حذف/اضافه کند
// (مثل حذف «ردولوت»)، فیلینگ را چندبخشی کند (خامه/میوه/مغزیجات)
// و گزینه‌های شرطی بسازد (شمع: بله/خیر ← نوع شمع).
//
// مدل:
//   CakeConfig
//     ├─ pricePerKg / leadDays / weights  (اعداد پایه)
//     └─ sections: List<CakeSection>
//          CakeSection
//            ├─ id / title
//            ├─ type: single (انتخاب یکی) | multi (چندتایی)
//            ├─ options: List<CakeOption>
//            └─ subsections: List<CakeSection>  (بخش‌های تو در تو)
//          CakeOption
//            ├─ id / label
//            └─ children: List<CakeSection>  (وقتی این گزینه انتخاب شود باز می‌شود)

/// نوع انتخاب در یک بخش.
class CakeOptionType {
  /// فقط یکی را می‌شود انتخاب کرد (طعم کیک).
  static const single = 'single';

  /// چندتایی را می‌شود تیک زد (مغزیجات، شمع).
  static const multi = 'multi';

  static String fa(String t) => t == multi ? 'چندتایی (تیک‌دار)' : 'تکی';
  static bool isMulti(String t) => t == multi;
}

/// یک گزینه داخل بخش. [children] زیرشاخه‌هایی است که با انتخاب
/// این گزینه باز می‌شوند (مثل «مغزیجات» ← «بادام، گردو، ...»).
class CakeOption {
  final String id;
  final String label;
  final List<CakeSection> children;

  const CakeOption({
    required this.id,
    required this.label,
    this.children = const [],
  });

  CakeOption copyWith({
    String? label,
    List<CakeSection>? children,
  }) {
    return CakeOption(
      id: id,
      label: label ?? this.label,
      children: children ?? this.children,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'children': [for (final c in children) c.toJson()],
      };

  factory CakeOption.fromJson(Map<String, dynamic> m) => CakeOption(
        id: '${m['id'] ?? ''}',
        label: '${m['label'] ?? ''}',
        children: CakeSection.fromList(m['children']),
      );

  static List<CakeOption> _optionsFrom(dynamic raw) {
    if (raw is! List) return const [];
    final out = <CakeOption>[];
    for (final e in raw.whereType<Map>()) {
      final o = CakeOption.fromJson(Map<String, dynamic>.from(e));
      if (o.id.isNotEmpty && o.label.isNotEmpty) out.add(o);
    }
    return out;
  }
}

/// یک بخش از صفحه (مثل «طعم کیک» یا «خامه» داخل فیلینگ).
class CakeSection {
  final String id;
  final String title;
  final String type; // single | multi
  final List<CakeOption> options;
  final List<CakeSection> subsections;

  const CakeSection({
    required this.id,
    required this.title,
    this.type = CakeOptionType.single,
    this.options = const [],
    this.subsections = const [],
  });

  bool get isMulti => CakeOptionType.isMulti(type);

  CakeSection copyWith({
    String? title,
    String? type,
    List<CakeOption>? options,
    List<CakeSection>? subsections,
  }) {
    return CakeSection(
      id: id,
      title: title ?? this.title,
      type: type ?? this.type,
      options: options ?? this.options,
      subsections: subsections ?? this.subsections,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'type': type,
        'options': [for (final o in options) o.toJson()],
        'subsections': [for (final s in subsections) s.toJson()],
      };

  factory CakeSection.fromJson(Map<String, dynamic> m) => CakeSection(
        id: '${m['id'] ?? ''}',
        title: '${m['title'] ?? ''}',
        type: '${m['type'] ?? CakeOptionType.single}',
        options: CakeOption._optionsFrom(m['options']),
        subsections: CakeSection.fromList(m['subsections']),
      );

  /// لیست بخش‌ها از JSON؛ خراب/بی‌id/بی‌عنوان دور ریخته می‌شود.
  static List<CakeSection> fromList(dynamic raw) {
    if (raw is! List) return const [];
    final out = <CakeSection>[];
    for (final e in raw.whereType<Map>()) {
      final s = CakeSection.fromJson(Map<String, dynamic>.from(e));
      if (s.id.isNotEmpty && s.title.isNotEmpty) out.add(s);
    }
    return out;
  }

  /// همه idهای این درخت (برای ساخت id یکتا در پنل مدیر).
  void collectIds(Set<String> into) {
    into.add(id);
    for (final o in options) {
      into.add(o.id);
      for (final c in o.children) {
        c.collectIds(into);
      }
    }
    for (final s in subsections) {
      s.collectIds(into);
    }
  }
}

/// کل پیکربندی کیک سفارشی.
class CakeConfig {
  /// قیمت هر کیلو (تومان).
  final int pricePerKg;
  /// حداقل روزهای آماده‌سازی.
  final int leadDays;
  /// وزن‌های قابل انتخاب (کیلوگرم).
  final List<double> weights;
  final List<CakeSection> sections;

  const CakeConfig({
    this.pricePerKg = 380000,
    this.leadDays = 3,
    this.weights = const [1.0, 1.5, 2.0, 3.0, 4.0, 5.0],
    this.sections = const [],
  });

  CakeConfig copyWith({
    int? pricePerKg,
    int? leadDays,
    List<double>? weights,
    List<CakeSection>? sections,
  }) {
    return CakeConfig(
      pricePerKg: pricePerKg ?? this.pricePerKg,
      leadDays: leadDays ?? this.leadDays,
      weights: weights ?? this.weights,
      sections: sections ?? this.sections,
    );
  }

  /// همه idهای موجود (برای تولید id یکتا).
  Set<String> allIds() {
    final s = <String>{};
    for (final sec in sections) {
      sec.collectIds(s);
    }
    return s;
  }

  Map<String, dynamic> toJson() => {
        'pricePerKg': pricePerKg,
        'leadDays': leadDays,
        'weights': [for (final w in weights) w],
        'sections': [for (final s in sections) s.toJson()],
      };

  factory CakeConfig.fromJson(Map<String, dynamic> m) {
    final wRaw = m['weights'];
    final weights = <double>[];
    if (wRaw is List) {
      for (final e in wRaw) {
        final v = double.tryParse('$e');
        if (v != null && v > 0 && v <= 50) weights.add(v);
      }
    }
    return CakeConfig(
      pricePerKg: _int(m['pricePerKg'], 380000, min: 1000),
      leadDays: _int(m['leadDays'], 3, min: 0, max: 60),
      weights: weights.isEmpty
          ? const [1.0, 1.5, 2.0, 3.0, 4.0, 5.0]
          : weights,
      sections: CakeSection.fromList(m['sections']),
    );
  }

  static int _int(dynamic v, int fallback, {int min = 0, int? max}) {
    final parsed = v is int ? v : int.tryParse('$v');
    if (parsed == null) return fallback;
    if (parsed < min) return fallback;
    if (max != null && parsed > max) return fallback;
    return parsed;
  }

  /// قیمت کیک بر اساس وزن. وزن نامعتبر → null.
  int? priceFor(double weightKg) {
    if (!weights.any((w) => w == weightKg)) return null;
    return (weightKg * pricePerKg).round();
  }
}

// ---------------- پیش‌فرض‌ها ----------------

const List<double> _defaultWeights = [1.0, 1.5, 2.0, 3.0, 4.0, 5.0];

/// بخش پیش‌فرض «طعم کیک» — تکی، با گزینه «مغزیجات» که زیرشاخه دارد.
const List<CakeOption> _defaultFlavors = [
  CakeOption(id: 'fl_vanilla', label: 'وانیلی'),
  CakeOption(id: 'fl_choco', label: 'شکلاتی'),
  CakeOption(id: 'fl_coffee', label: 'نسکافه‌ای'),
  CakeOption(id: 'fl_red', label: 'ردولوت'),
  CakeOption(id: 'fl_lemon', label: 'لیمویی'),
  CakeOption(id: 'fl_carrot', label: 'هویج و گردو'),
  CakeOption(
    id: 'fl_nuts',
    label: 'مغزیجات',
    children: [
      CakeSection(
        id: 'fl_nuts_kind',
        title: 'مغزیجات کدام باشد؟',
        type: CakeOptionType.multi,
        options: [
          CakeOption(id: 'fl_nut_almond', label: 'بادام'),
          CakeOption(id: 'fl_nut_walnut', label: 'گردو'),
          CakeOption(id: 'fl_nut_hazelnut', label: 'فندق'),
          CakeOption(id: 'fl_nut_pistachio', label: 'پسته'),
          CakeOption(id: 'fl_nut_raisin', label: 'کشمش'),
          CakeOption(id: 'fl_nut_mix', label: 'مخلوط'),
        ],
      ),
    ],
  ),
];

/// فیلینگ سه‌بخشی: خامه، میوه، مغزیجات (همه چندتایی).
const List<CakeSection> _defaultFillings = [
  CakeSection(
    id: 'fl_cream',
    title: 'خامه',
    type: CakeOptionType.multi,
    options: [
      CakeOption(id: 'fc_vanilla', label: 'خامه وانیلی'),
      CakeOption(id: 'fc_choco', label: 'خامه شکلات'),
      CakeOption(id: 'fc_cocoa', label: 'خامه نارگیل'),
    ],
  ),
  CakeSection(
    id: 'fl_fruit',
    title: 'میوه',
    type: CakeOptionType.multi,
    options: [
      CakeOption(id: 'ff_season', label: 'میوه فصل'),
      CakeOption(id: 'ff_strawberry', label: 'توت فرنگی'),
      CakeOption(id: 'ff_peach', label: 'هلو'),
      CakeOption(id: 'ff_pomegranate', label: 'انار'),
      CakeOption(id: 'ff_kiwi', label: 'کیوی'),
    ],
  ),
  CakeSection(
    id: 'fl_nuts',
    title: 'مغزیجات',
    type: CakeOptionType.multi,
    options: [
      CakeOption(id: 'fn_almond', label: 'بادام'),
      CakeOption(id: 'fn_walnut', label: 'گردو'),
      CakeOption(id: 'fn_hazelnut', label: 'فندق'),
      CakeOption(id: 'fn_pistachio', label: 'پسته'),
      CakeOption(id: 'fn_raisin', label: 'کشمش'),
      CakeOption(id: 'fn_mix', label: 'مخلوط'),
    ],
  ),
];

/// بخش شمع: بله/خیر؛ با انتخاب «بله» زیرشاخه «نوع شمع» باز می‌شود.
const List<CakeOption> _defaultCandles = [
  CakeOption(
    id: 'cand_yes',
    label: 'بله، شمع می‌خوام',
    children: [
      CakeSection(
        id: 'cand_type',
        title: 'نوع شمع',
        type: CakeOptionType.single,
        options: [
          CakeOption(id: 'ct_single', label: 'شمع تکی'),
          CakeOption(id: 'ct_multi', label: 'شمع چندتایی'),
        ],
      ),
    ],
  ),
  CakeOption(id: 'cand_no', label: 'خیر، شمع نمی‌خوام'),
];

/// پیش‌فرض کامل صفحه کیک‌ساز.
const CakeConfig defaultCakeConfig = CakeConfig(
  pricePerKg: 380000,
  leadDays: 3,
  weights: _defaultWeights,
  sections: [
    CakeSection(
      id: 'sec_flavor',
      title: 'طعم کیک',
      type: CakeOptionType.single,
      options: _defaultFlavors,
    ),
    CakeSection(
      id: 'sec_filling',
      title: 'فیلینگ',
      type: CakeOptionType.multi,
      // فیلینگ خودش گزینه ندارد؛ فقط سه زیربخش دارد.
      subsections: _defaultFillings,
    ),
    CakeSection(
      id: 'sec_candle',
      title: 'شمع',
      type: CakeOptionType.multi,
      options: _defaultCandles,
    ),
  ],
);