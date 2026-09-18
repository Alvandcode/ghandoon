import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/qand_theme.dart';
import '../config/app_config.dart';
import '../services/supabase_service.dart';

class ChatScreen extends StatefulWidget {
  /// وقتی چت داخل تب خانه جاسازی شده، دکمه برگشت نباید `pop` کند
  /// (روتی برای برگشت نیست و اپ می‌پرد). در این حالت false بده.
  final bool showBackButton;
  const ChatScreen({super.key, this.showBackButton = true});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _ctl = TextEditingController();
  final _scroll = ScrollController();
  static const _kChat = 'qand_chat_v1';
  static const _kMax = 200;
  final List<Map<String, dynamic>> _msgs = [
    {'me': false, 't': 'سلام! به قنادی قند خوش اومدی 🌸 سوالت رو بپرس، مدیر جواب میده.'},
  ];
  // شفاف‌سازی: چت هنوز به سرور وصل نیست (پیام زنده بعد از اتصال جدول messages).
  bool get _isDemo => SupabaseService.clientOrNull() == null;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  /// تاریخچه لوکال تا با بستن اپ پاک نشود. (نسخه بعدی: جدول messages در سوپابیس)
  Future<void> _restore() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_kChat);
      if (raw != null && raw.isNotEmpty) {
        final list = (jsonDecode(raw) as List)
            .whereType<Map>()
            .map<Map<String, dynamic>>(
                (e) => {'me': e['me'] == true, 't': '${e['t'] ?? ''}'})
            .where((e) => ('${e['t']}'.trim().isNotEmpty))
            .take(_kMax)
            .toList();
        if (list.isNotEmpty && mounted) {
          setState(() {
            _msgs
              ..clear()
              ..addAll(list);
          });
        }
      }
    } catch (_) {
      // تاریخچه خراب = شروع تازه، بدون کرش
    } finally {
      _jumpToEnd();
    }
  }

  Future<void> _persist() async {
    try {
      final p = await SharedPreferences.getInstance();
      final keep = _msgs.length > _kMax ? _msgs.sublist(_msgs.length - _kMax) : _msgs;
      await p.setString(_kChat, jsonEncode(keep));
    } catch (_) {
      // ذخیره ناموفق نباید ارسال پیام را خراب کند
    }
  }

  @override
  void dispose() {
    _ctl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    final t = _ctl.text.trim();
    if (t.isEmpty) return;
    // سقف طول پیام تا SharedPreferences باد نکند
    final clipped = t.length > 1000 ? t.substring(0, 1000) : t;
    setState(() {
      _msgs.add({'me': true, 't': clipped});
      // پاسخ خودکار دمویی؛ با اتصال سوپابیس پیام واقعی به مدیر می‌رود
      _msgs.add({'me': false, 't': 'پیامت ثبت شد، مدیر به‌زودی جواب میده 🙏'});
      if (_msgs.length > _kMax) {
        _msgs.removeRange(0, _msgs.length - _kMax);
      }
    });
    _ctl.clear();
    _persist();
    _jumpToEnd();
  }

  void _jumpToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _call() async {
    final uri = Uri.parse('tel:${AppConfig.supportPhone}');
    if (!await launchUrl(uri)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('برقراری تماس ممکن نشد')));
    }
  }

  Future<void> _whatsapp() async {
    final uri = Uri.parse('https://wa.me/${AppConfig.whatsappNumber}');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('باز کردن واتساپ ممکن نشد')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(90),
        child: Container(decoration: QandTheme.headerGradient(radius: 24),
          child: SafeArea(child: Row(children: [
            if (widget.showBackButton)
              IconButton(onPressed: () => Navigator.maybePop(context), icon: const Icon(Icons.arrow_forward, color: Colors.white)),
            const CircleAvatar(backgroundColor: Colors.white, child: Text('👩‍🍳')),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('مدیر قنادی قند', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              Text(_isDemo ? 'حالت دمو — پیام‌ها هنوز به مدیر نمی‌رسند' : 'آنلاین', style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ]),
            const Spacer(),
            IconButton(onPressed: _call, icon: const Icon(Icons.call, color: Colors.white)),
            IconButton(onPressed: _whatsapp, icon: const Icon(Icons.chat, color: Colors.white)),
          ]))),
      ),
      body: Column(children: [
        Expanded(child: ListView.builder(
          controller: _scroll,
          padding: const EdgeInsets.all(14),
          itemCount: _msgs.length,
          itemBuilder: (_, i) {
            final m = _msgs[i];
            final me = m['me'] as bool;
            return Align(
              alignment: me ? Alignment.centerLeft : Alignment.centerRight,
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: me ? QandTheme.red : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
                ),
                child: Text('${m['t']}', style: TextStyle(color: me ? Colors.white : Colors.black87)),
              ),
            );
          },
        )),
        SafeArea(child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [
          Expanded(child: TextField(controller: _ctl, decoration: const InputDecoration(hintText: 'پیامت به مدیر...'))),
          const SizedBox(width: 8),
          IconButton.filled(onPressed: _send, icon: const Icon(Icons.send), style: IconButton.styleFrom(backgroundColor: QandTheme.red, foregroundColor: Colors.white)),
        ]))),
      ]),
    );
  }
}
