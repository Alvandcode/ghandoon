import 'package:flutter/material.dart';
import '../models/cake_config.dart';
import '../services/cake_config_service.dart';
import '../theme/qand_theme.dart';

/// ویرایشگر «کیک تولد سفارشی» برای پنل مدیر.
///
/// مدیر می‌تواند:
/// - وزن‌ها و قیمت هر کیلو و روزهای آماده‌سازی را عوض کند
/// - بخش جدید بسازد/حذف کند/عنوانش را عوض کند
/// - نوع هر بخش را بگذارد تکی یا چندتایی (تیک‌دار)
/// - گزینه اضافه/حذف/تغییر نام کند
/// - برای هر گزینه «زیرشاخه» بسازد (مثل مغزیجات ← نوع مغزیجات)
/// - زیربخش بسازد (مثل فیلینگ ← خامه/میوه/مغزیجات)
class CakeConfigTab extends StatefulWidget {
  /// بعد از ذخیره موفق به parent خبر می‌دهیم (تا تب دیگر رفرش شود).
  final VoidCallback? onSaved;
  const CakeConfigTab({super.key, this.onSaved});

  @override
  State<CakeConfigTab> createState() => _CakeConfigTabState();
}

class _CakeConfigTabState extends State<CakeConfigTab> {
  CakeConfig? _cfg;
  bool _busy = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cfg = await CakeConfigService().load();
    if (!mounted) return;
    setState(() {
      _cfg = cfg;
      _loading = false;
    });
  }

  String _newId(String prefix) {
    final taken = _cfg?.allIds() ?? <String>{};
    return CakeConfigService.uniqueId(taken, prefix);
  }

  void _update(CakeConfig next) => setState(() => _cfg = next);

  CakeConfig get _c => _cfg ?? defaultCakeConfig;

  // ---------- عملیات ساختاری ----------

  /// جایگزینی یک بخش در لیست (بر اساس id) و برگرداندن لیست جدید.
  List<CakeSection> _swap(
      List<CakeSection> list, CakeSection original, CakeSection updated) {
    return [
      for (final s in list) s.id == original.id ? updated : s,
    ];
  }

  void _editSectionTitle(CakeSection section, String title) {
    _update(_c.copyWith(
      sections: _swap(
          _c.sections, section, section.copyWith(title: title)),
    ));
  }

  void _editSectionType(CakeSection section, String type) {
    _update(_c.copyWith(
      sections: _swap(
          _c.sections, section, section.copyWith(type: type)),
    ));
  }

  void _addOption(CakeSection section) async {
    final label = await _askText('نام گزینه جدید', 'مثلاً: پسته');
    if (label == null || label.trim().isEmpty) return;
    final opt = CakeOption(id: _newId('opt'), label: label.trim());
    _update(_c.copyWith(
      sections: _swap(_c.sections, section,
          section.copyWith(options: [...section.options, opt])),
    ));
  }

  void _editOptionLabel(CakeSection section, CakeOption opt, String label) {
    _update(_c.copyWith(
      sections: _swap(
        _c.sections,
        section,
        section.copyWith(options: [
          for (final o in section.options)
            if (o.id == opt.id) o.copyWith(label: label) else o
        ]),
      ),
    ));
  }

  Future<void> _removeOption(CakeSection section, CakeOption opt) async {
    final ok = await _confirm(
        'حذف گزینه', '«${opt.label}» حذف شود؟ زیرشاخه‌هایش هم می‌روند.');
    if (!ok) return;
    _update(_c.copyWith(
      sections: _swap(
        _c.sections,
        section,
        section.copyWith(options: [
          for (final o in section.options)
            if (o.id != opt.id) o
        ]),
      ),
    ));
  }

  /// افزودن زیرشاخه به یک گزینه (وقتی گزینه تیک خورد، این‌ها باز می‌شوند).
  Future<void> _addChild(CakeOption opt) async {
    final title = await _askText('عنوان زیرشاخه', 'مثلاً: نوع مغزیجات');
    if (title == null || title.trim().isEmpty) return;
    final child = CakeSection(
      id: _newId('sub'),
      title: title.trim(),
      type: CakeOptionType.multi,
    );
    _replaceOptionChildren(opt, [...opt.children, child]);
  }

  /// افزودن زیربخش مستقیم به یک بخش (مثل «خامه» زیر «فیلینگ»).
  Future<void> _addSubsection(CakeSection section) async {
    final title = await _askText('عنوان زیربخش', 'مثلاً: خامه');
    if (title == null || title.trim().isEmpty) return;
    final sub = CakeSection(
      id: _newId('sub'),
      title: title.trim(),
      type: CakeOptionType.multi,
    );
    _update(_c.copyWith(
      sections: _swap(_c.sections, section,
          section.copyWith(subsections: [...section.subsections, sub])),
    ));
  }

  void _removeSubsection(CakeSection section, CakeSection sub) async {
    final ok = await _confirm(
        'حذف زیربخش', '«${sub.title}» و همه گزینه‌هایش حذف شود؟');
    if (!ok) return;
    _update(_c.copyWith(
      sections: _swap(
        _c.sections,
        section,
        section.copyWith(
            subsections: [
              for (final s in section.subsections)
                if (s.id != sub.id) s
            ]),
      ),
    ));
  }

  /// جایگزینی زیرشاخه‌های یک گزینه (برای ویرایش درجا).
  void _replaceOptionChildren(CakeOption opt, List<CakeSection> children) {
    List<CakeSection> walk(List<CakeSection> list) => [
          for (final s in list) s.copyWith(
                options: [
                  for (final o in s.options)
                    if (o.id == opt.id)
                      o.copyWith(children: children)
                    else
                      o
                ],
                subsections: walk(s.subsections),
              ),
        ];
    _update(_c.copyWith(sections: walk(_c.sections)));
  }

  /// ویرایش زیرشاخه‌ی یک گزینه (مثل «نوع مغزیجات»).
  void _editChildSection(CakeOption opt, CakeSection child, CakeSection next) {
    List<CakeSection> walk(List<CakeSection> list) => [
          for (final s in list) s.copyWith(
                options: [
                  for (final o in s.options)
                    if (o.id == opt.id)
                      o.copyWith(
                          children: [
                            for (final c in o.children)
                              if (c.id == child.id) next else c
                          ])
                    else
                      o
                ],
                subsections: walk(s.subsections),
              ),
        ];
    _update(_c.copyWith(sections: walk(_c.sections)));
  }

  void _addChildOption(CakeOption opt, CakeSection child) async {
    final label = await _askText('نام گزینه', 'مثلاً: بادام');
    if (label == null || label.trim().isEmpty) return;
    final o = CakeOption(id: _newId('opt'), label: label.trim());
    _editChildSection(opt, child,
        child.copyWith(options: [...child.options, o]));
  }

  /// افزودن بخش سطح بالا (مثل یک «مغزیجات» مستقل).
  Future<void> _addTopSection() async {
    final title = await _askText('عنوان بخش جدید', 'مثلاً: مغزیجات');
    if (title == null || title.trim().isEmpty) return;
    final sec = CakeSection(
      id: _newId('sec'),
      title: title.trim(),
      type: CakeOptionType.multi,
    );
    _update(_c.copyWith(sections: [..._c.sections, sec]));
  }

  Future<void> _removeTopSection(CakeSection section) async {
    final ok = await _confirm('حذف بخش',
        'بخش «${section.title}» و همه گزینه‌ها/زیرشاخه‌هایش حذف شود؟');
    if (!ok) return;
    _update(_c.copyWith(
      sections: [for (final s in _c.sections) if (s.id != section.id) s],
    ));
  }

  // ---------- ذخیره ----------

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final ok = await CakeConfigService().save(_c);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok
            ? 'تنظیمات کیک سفارشی ذخیره شد ✅'
            : 'فقط روی همین گوشی ذخیره شد (سرور در دسترس نیست)'),
      ));
      widget.onSaved?.call();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    final ok = await _confirm(
        'بازنشانی', 'همه به حالت پیش‌فرض برگردد؟ تغییراتت پاک می‌شود.');
    if (!ok) return;
    setState(() {
      _cfg = defaultCakeConfig;
    });
    await _save();
  }

  Future<String?> _askText(String title, String hint) async {
    final ctl = TextEditingController();
    final res = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: TextField(
            controller: ctl, autofocus: true, decoration: InputDecoration(hintText: hint)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('انصراف')),
          ElevatedButton(
              onPressed: () => Navigator.pop(c, ctl.text),
              child: const Text('تایید')),
        ],
      ),
    );
    ctl.dispose();
    return res;
  }

  Future<bool> _confirm(String title, String msg) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(msg),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('انصراف')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    return res == true;
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(14),
            children: [
              _numbersCard(),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('بخش‌های صفحه',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  TextButton.icon(
                    onPressed: _addTopSection,
                    icon: const Icon(Icons.add),
                    label: const Text('بخش جدید'),
                  ),
                ],
              ),
              if (_c.sections.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: Text('بخشی نیست — یکی بساز')),
                ),
              for (final s in _c.sections) _sectionCard(s, 0),
              const SizedBox(height: 80),
            ],
          ),
        ),
        // نوار پایین: ذخیره/بازنشانی همیشه در دسترس
        SafeArea(
          child: Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _busy ? null : _save,
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('ذخیره تنظیمات کیک'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _reset,
                  child: const Text('پیش‌فرض'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _numbersCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('اعداد پایه',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _numField('قیمت هر کیلو (تومان)', _c.pricePerKg,
                      (v) => _update(_c.copyWith(pricePerKg: v))),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _numField('روز آماده‌سازی', _c.leadDays,
                      (v) => _update(_c.copyWith(leadDays: v))),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: _c.weights.map((w) => _fmt(w)).join('، '),
              decoration: const InputDecoration(
                labelText: 'وزن‌ها (با کاما جدا کن)',
                hintText: '1, 1.5, 2, 3',
              ),
              onChanged: (raw) {
                final ws = <double>[];
                for (final part in raw.split(RegExp(r'[,،\s]+'))) {
                  final v = double.tryParse(part.trim());
                  if (v != null && v > 0 && v <= 50) ws.add(v);
                }
                if (ws.isNotEmpty) _update(_c.copyWith(weights: ws));
              },
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(double w) =>
      w.toString().replaceAll('.0', '').replaceAll('.', '.');

  Widget _numField(String label, int value, ValueChanged<int> onChanged) {
    final ctl = TextEditingController(text: '$value');
    return TextField(
      controller: ctl,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label),
      onChanged: (s) {
        final v = int.tryParse(s.trim());
        if (v != null) onChanged(v);
      },
    );
  }

  /// کارت یک بخش (باز/بسته شونده). سطح برای تورفتگی نمایش.
  Widget _sectionCard(CakeSection s, int depth) {
    return Padding(
      padding: EdgeInsets.only(left: depth * 12.0),
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ExpansionTile(
          initiallyExpanded: depth == 0,
          title: Text(s.title,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(
              '${CakeOptionType.fa(s.type)} • ${s.options.length} گزینه${s.subsections.isNotEmpty ? ' • ${s.subsections.length} زیربخش' : ''}',
              style: const TextStyle(fontSize: 11)),
          trailing: depth == 0
              ? IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _removeTopSection(s))
              : null,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // عنوان بخش
                  TextFormField(
                    initialValue: s.title,
                    decoration: const InputDecoration(
                        labelText: 'عنوان بخش', isDense: true),
                    onChanged: (v) =>
                        v.trim().isEmpty ? null : _editSectionTitle(s, v),
                  ),
                  const SizedBox(height: 8),
                  // نوع بخش
                  Row(
                    children: [
                      const Text('نوع:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(
                                value: CakeOptionType.single,
                                label: Text('تکی')),
                            ButtonSegment(
                                value: CakeOptionType.multi,
                                label: Text('چندتایی')),
                          ],
                          selected: {s.type},
                          onSelectionChanged: (sel) =>
                              _editSectionType(s, sel.first),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text('گزینه‌ها',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  for (final o in s.options) _optionRow(s, o),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => _addOption(s),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('افزودن گزینه'),
                    ),
                  ),
                  if (s.options.isEmpty && s.subsections.isEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => _addSubsection(s),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('افزودن زیربخش'),
                      ),
                    ),
                  if (s.subsections.isNotEmpty) ...[
                    const Divider(),
                    const Text('زیربخش‌ها',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                    for (final sub in s.subsections)
                      _subsectionRow(s, sub),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => _addSubsection(s),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('افزودن زیربخش (مثلاً خامه)'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _optionRow(CakeSection s, CakeOption o) {
    final hasKids = o.children.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: o.label,
                  decoration: const InputDecoration(
                    labelText: 'نام گزینه',
                    isDense: true,
                    hintText: 'مثلاً: خامه وانیلی',
                  ),
                  onChanged: (v) => v.trim().isEmpty
                      ? null
                      : _editOptionLabel(s, o, v),
                ),
              ),
              IconButton(
                tooltip: 'افزودن زیرشاخه (وقتی انتخاب شود باز می‌شود)',
                icon: const Icon(Icons.account_tree_outlined),
                onPressed: () => _addChild(o),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _removeOption(s, o),
              ),
            ],
          ),
          if (hasKids)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('↳ وقتی انتخاب شود:',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey)),
                  for (final c in o.children) _childEditor(o, c),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// ویرایشگر یک زیرشاخه‌ی شرطی (زیرمجموعه یک گزینه).
  Widget _childEditor(CakeOption parent, CakeSection child) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: QandTheme.cream,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: child.title,
                  decoration: const InputDecoration(
                      labelText: 'عنوان زیرشاخه', isDense: true),
                  onChanged: (v) => v.trim().isEmpty
                      ? null
                      : _editChildSection(parent, child,
                          child.copyWith(title: v)),
                ),
              ),
              TextButton(
                onPressed: () {
                  _editChildSection(
                      parent,
                      child,
                      child.copyWith(
                          type: child.isMulti
                              ? CakeOptionType.single
                              : CakeOptionType.multi));
                },
                child: Text(child.isMulti ? 'تکی کن' : 'چندتایی کن'),
              ),
            ],
          ),
          for (final co in child.options)
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: co.label,
                    decoration: const InputDecoration(
                        labelText: 'گزینه', isDense: true),
                    onChanged: (v) {
                      if (v.trim().isEmpty) return;
                      _editChildSection(
                          parent,
                          child,
                          child.copyWith(options: [
                            for (final x in child.options)
                              if (x.id == co.id) x.copyWith(label: v) else x
                          ]));
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18, color: Colors.red),
                  onPressed: () {
                    _editChildSection(
                        parent,
                        child,
                        child.copyWith(options: [
                          for (final x in child.options)
                            if (x.id != co.id) x
                        ]));
                  },
                ),
              ],
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _addChildOption(parent, child),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('گزینه', style: TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _subsectionRow(CakeSection parent, CakeSection sub) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              initialValue: sub.title,
              decoration: const InputDecoration(
                labelText: 'نام زیربخش',
                isDense: true,
                hintText: 'مثلاً: خامه',
              ),
              onChanged: (v) {
                if (v.trim().isEmpty) return;
                _update(_c.copyWith(
                  sections: _swap(
                    _c.sections,
                    parent,
                    parent.copyWith(subsections: [
                      for (final x in parent.subsections)
                        if (x.id == sub.id) x.copyWith(title: v) else x
                    ]),
                  ),
                ));
              },
            ),
          ),
          IconButton(
            tooltip: 'افزودن گزینه به این زیربخش',
            icon: const Icon(Icons.add),
            onPressed: () async {
              final label = await _askText('نام گزینه', 'مثلاً: خامه وانیلی');
              if (label == null || label.trim().isEmpty) return;
              final o = CakeOption(id: _newId('opt'), label: label.trim());
              _update(_c.copyWith(
                sections: _swap(
                  _c.sections,
                  parent,
                  parent.copyWith(subsections: [
                    for (final x in parent.subsections)
                      if (x.id == sub.id)
                        x.copyWith(options: [...x.options, o])
                      else
                        x
                  ]),
                ),
              ));
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () => _removeSubsection(parent, sub),
          ),
        ],
      ),
    );
  }
}