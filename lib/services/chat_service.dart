import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat_message.dart';
import 'supabase_service.dart';

/// چت واقعی مدیر↔مشتری روی جدول `messages` (+ باکت `chat-images` برای عکس).
/// - آنلاین: خواندن/نوشتن سرور + Realtime.
/// - آفلاین: همان رفتار دموی قبلی (تاریخچه لوکال + جواب خودکار).
/// نام مدیر در چت همیشه 'admin' است.
class ChatService {
  static const adminName = 'admin';
  static const bucket = 'chat-images';
  static const _kChat = 'qand_chat_v1';
  static const _kMax = 200;

  /// پیام‌های گفتگوی من با [peer] (قدیمی → جدید).
  Future<List<ChatMessage>> thread(String me, String peer) async {
    final client = SupabaseService.clientOrNull();
    if (client == null) return _localThread();
    try {
      final rows = await client
          .from('messages')
          .select()
          .or('sender_name.eq.$me,receiver_name.eq.$me')
          .order('created_at', ascending: true)
          .limit(500);
      final all = (rows as List<dynamic>)
          .map((e) => ChatMessage.fromMap(
              Map<String, dynamic>.from(e as Map<String, dynamic>)))
          .where((m) => m.sender.isNotEmpty && m.text.isNotEmpty)
          .toList();
      return [
        for (final m in all)
          if ((m.sender == me && m.receiver == peer) ||
              (m.sender == peer && m.receiver == me))
            m
      ];
    } catch (_) {
      return _localThread();
    }
  }

  /// همه پیام‌ها برای مدیر (گروه‌بندی در UI).
  Future<List<ChatMessage>> allForAdmin() async {
    final client = SupabaseService.clientOrNull();
    if (client == null) return [];
    try {
      final rows = await client
          .from('messages')
          .select()
          .order('created_at', ascending: false)
          .limit(300);
      return (rows as List<dynamic>)
          .map((e) => ChatMessage.fromMap(
              Map<String, dynamic>.from(e as Map<String, dynamic>)))
          .where((m) => m.sender.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// ارسال متن/عکس. false یعنی ناموفق (آفلاین یا خطا).
  Future<bool> send({
    required String from,
    required String to,
    String text = '',
    String? imageUrl,
  }) async {
    final client = SupabaseService.clientOrNull();
    if (client == null) {
      await _localAdd(from: from, text: text);
      return false;
    }
    try {
      final msg = ChatMessage(
          id: '', sender: from, receiver: to, text: text,
          imageUrl: imageUrl, createdAt: '');
      await client.from('messages').insert(msg.toMap());
      return true;
    } catch (_) {
      return false;
    }
  }

  /// آپلود عکس چت. null یعنی ناموفق.
  Future<String?> uploadImage(
      {required String localPath, required String username}) async {
    final client = SupabaseService.clientOrNull();
    if (client == null) return null;
    try {
      final file = File(localPath);
      if (!await file.exists()) return null;
      final base = _baseName(localPath);
      final safeUser = username.trim().isEmpty
          ? 'guest'
          : username.trim().replaceAll(RegExp(r'[^\w\-@.]+'), '_');
      final objectPath =
          '$safeUser/${DateTime.now().millisecondsSinceEpoch}_$base';
      await client.storage.from(bucket).upload(
            objectPath,
            file,
            fileOptions:
                const FileOptions(upsert: true, contentType: 'image/jpeg'),
          );
      final url = client.storage.from(bucket).getPublicUrl(objectPath);
      return url.isEmpty ? null : url;
    } catch (_) {
      return null;
    }
  }

  /// اشتراک لحظه‌ای پیام‌ها. [onEvent] را صدا می‌زند؛ خروجی برای لغو.
  RealtimeChannel? watch(void Function() onEvent) {
    final client = SupabaseService.clientOrNull();
    if (client == null) return null;
    try {
      final ch = client.channel('chat-msgs');
      ch.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'messages',
        callback: (_) => onEvent(),
      );
      ch.subscribe();
      return ch;
    } catch (_) {
      return null;
    }
  }

  Future<void> unwatch(RealtimeChannel? ch) async {
    if (ch == null) return;
    try {
      await ch.unsubscribe();
    } catch (_) {}
  }

  String _baseName(String path) {
    final p = path.replaceAll('\\', '/');
    final i = p.lastIndexOf('/');
    var name = i >= 0 ? p.substring(i + 1) : p;
    name = name.replaceAll(RegExp(r'[^\w\-.]+'), '_');
    return name.isEmpty ? 'chat.jpg' : name;
  }

  // ---------- حالت آفلاین/دمو (رفتار قبلی) ----------

  Future<List<ChatMessage>> _localThread() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_kChat);
      if (raw == null || raw.isEmpty) return [];
      return (jsonDecode(raw) as List)
          .whereType<Map>()
          .map((e) => ChatMessage(
                id: '',
                sender: e['me'] == true ? 'me' : adminName,
                receiver: '',
                text: '${e['t'] ?? ''}',
                createdAt: '',
              ))
          .where((m) => m.text.trim().isNotEmpty)
          .take(_kMax)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _localAdd({required String from, required String text}) async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_kChat);
      final list = <Map<String, dynamic>>[
        if (raw != null && raw.isNotEmpty)
          ...(jsonDecode(raw) as List).whereType<Map>().map(
              (e) => {'me': e['me'] == true, 't': '${e['t'] ?? ''}'}),
      ];
      list.add({'me': true, 't': text});
      list.add({'me': false, 't': 'پیامت ثبت شد، مدیر به‌زودی جواب میده 🙏'});
      while (list.length > _kMax) {
        list.removeAt(0);
      }
      await p.setString(_kChat, jsonEncode(list));
    } catch (_) {}
  }
}
