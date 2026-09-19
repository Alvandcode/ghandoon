import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/qand_theme.dart';
import '../config/app_config.dart';
import '../models/chat_message.dart';
import '../services/chat_service.dart';
import '../services/supabase_service.dart';

/// چت مدیر↔مشتری (واقعی روی سوپابیس + fallback دموی آفلاین).
/// - مشتری: peer='admin' (پیش‌فرض).
/// - مدیر: peer=نام مشتری، username=نام مدیر.
/// وقتی چت داخل تب خانه جاسازی شده، showBackButton=false بده.
class ChatScreen extends StatefulWidget {
  final String username;
  final String peer;
  final bool showBackButton;
  const ChatScreen({
    super.key,
    required this.username,
    this.peer = ChatService.adminName,
    this.showBackButton = true,
  });
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _ctl = TextEditingController();
  final _scroll = ScrollController();
  List<ChatMessage> _msgs = [];
  bool _sending = false;
  RealtimeChannel? _channel;
  Timer? _poll;

  bool get _isDemo => SupabaseService.clientOrNull() == null;
  bool get _isAdmin =>
      widget.username == ChatService.adminName;

  @override
  void initState() {
    super.initState();
    _load();
    _channel = ChatService().watch(() => _load(silent: true));
    // پشتیبان پولینگ اگر Realtime وصل نشود
    _poll = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) _load(silent: true);
    });
  }

  Future<void> _load({bool silent = false}) async {
    final list =
        await ChatService().thread(widget.username, widget.peer);
    if (!mounted) return;
    final changed = list.length != _msgs.length ||
        (list.isNotEmpty &&
            _msgs.isNotEmpty &&
            list.last.id != _msgs.last.id);
    if (silent && !changed) return;
    setState(() => _msgs = list);
    _jumpToEnd();
  }

  @override
  void dispose() {
    ChatService().unwatch(_channel);
    _poll?.cancel();
    _ctl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final t = _ctl.text.trim();
    if (t.isEmpty || _sending) return;
    final clipped = t.length > 1000 ? t.substring(0, 1000) : t;
    setState(() => _sending = true);
    try {
      final ok = await ChatService().send(
        from: widget.username,
        to: widget.peer,
        text: clipped,
      );
      _ctl.clear();
      await _load();
      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('آفلاین هستی؛ پیام در تاریخچه محلی ماند 🙏')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendImage() async {
    if (_sending) return;
    try {
      final img = await ImagePicker()
          .pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (img == null || !mounted) return;
      setState(() => _sending = true);
      final url = await ChatService()
          .uploadImage(localPath: img.path, username: widget.username);
      if (url == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('آپلود عکس ناموفق بود؛ اتصال را بررسی کن')));
        return;
      }
      await ChatService().send(
        from: widget.username,
        to: widget.peer,
        text: '📷 عکس',
        imageUrl: url,
      );
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ارسال عکس ناموفق بود')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
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
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('برقراری تماس ممکن نشد')));
    }
  }

  Future<void> _whatsapp() async {
    final uri = Uri.parse('https://wa.me/${AppConfig.whatsappNumber}');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('باز کردن واتساپ ممکن نشد')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final peerTitle =
        _isAdmin ? 'گفتگو با ${widget.peer}' : 'مدیر قندون';
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(90),
        child: Container(
            decoration: QandTheme.headerGradient(radius: 24),
          child: SafeArea(
              child: Row(children: [
            if (widget.showBackButton)
              IconButton(
                  onPressed: () => Navigator.maybePop(context),
                  icon:
                      const Icon(Icons.arrow_forward, color: Colors.white))
            else
              const SizedBox(width: 12),
            const CircleAvatar(
                radius: 26,
                backgroundColor: Colors.white,
                child: Text('👩‍🍳', style: TextStyle(fontSize: 30))),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(peerTitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            fontFamily: QandTheme.titleFont)),
                    Text(
                        _isDemo
                            ? 'حالت دمو — پیام‌ها هنوز به مدیر نمی‌رسند'
                            : 'آنلاین',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13)),
                  ]),
            ),
            if (!_isAdmin) ...[
              IconButton(
                  onPressed: _call,
                  icon: const Icon(Icons.call, color: Colors.white)),
              IconButton(
                  onPressed: _whatsapp,
                  icon: const Icon(Icons.chat, color: Colors.white)),
            ] else
              const SizedBox(width: 12),
          ]))),
      ),
      body: Column(children: [
        Expanded(
            child: _msgs.isEmpty
                ? const Center(
                    child: Text(
                        'هنوز پیامی نیست 👋\nسلام کن یا عکس کیکت را بفرست.',
                        textAlign: TextAlign.center))
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(14),
                    itemCount: _msgs.length,
                    itemBuilder: (_, i) => _bubble(_msgs[i]),
                  )),
        SafeArea(
            child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  IconButton(
                    tooltip: 'ارسال عکس کیک پیشنهادی',
                    onPressed: _sending ? null : _sendImage,
                    icon: const Icon(Icons.photo_library_outlined,
                        color: QandTheme.red),
                  ),
                  Expanded(
                      child: TextField(
                          controller: _ctl,
                          onSubmitted: (_) => _send(),
                          decoration: const InputDecoration(
                              hintText: 'پیامت... (می‌توانی عکس هم بفرستی)'))),
                  const SizedBox(width: 8),
                  IconButton.filled(
                      onPressed: _sending ? null : _send,
                      icon: _sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.send),
                      style: IconButton.styleFrom(
                          backgroundColor: QandTheme.red,
                          foregroundColor: Colors.white)),
                ]))),
      ]),
    );
  }

  Widget _bubble(ChatMessage m) {
    final me = m.sender == widget.username ||
        (widget.username != ChatService.adminName &&
            m.sender != ChatService.adminName &&
            m.sender == 'me');
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (m.hasImage)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: m.imageUrl!,
                    width: 200,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                        width: 200,
                        height: 140,
                        color: Colors.grey.shade200,
                        child: const Center(
                            child: CircularProgressIndicator())),
                    errorWidget: (_, __, ___) => const Icon(
                        Icons.broken_image,
                        color: QandTheme.red),
                  ),
                ),
              ),
            Text(m.text,
                style: TextStyle(
                    color: me ? Colors.white : Colors.black87)),
          ],
        ),
      ),
    );
  }
}
