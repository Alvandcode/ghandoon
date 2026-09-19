import 'package:flutter_test/flutter_test.dart';
import 'package:qand_app/models/chat_message.dart';

void main() {
  group('ChatMessage', () {
    test('fromMap هر دو نام‌گذاری قدیمی/جدید را می‌خواند', () {
      final a = ChatMessage.fromMap({
        'id': '1',
        'sender_name': 'ali',
        'receiver_name': 'admin',
        'text': 'سلام',
        'image_url': 'https://x/a.jpg',
        'created_at': 't',
      });
      expect(a.sender, 'ali');
      expect(a.receiver, 'admin');
      expect(a.hasImage, isTrue);

      final b = ChatMessage.fromMap({'id': '2', 'text': 'x'});
      expect(b.sender, '');
      expect(b.hasImage, isFalse);
    });

    test('toMap فقط ستون‌های سرور را می‌فرستد', () {
      const m = ChatMessage(
          id: 'x',
          sender: 'ali',
          receiver: 'admin',
          text: 'سلام',
          createdAt: '');
      final map = m.toMap();
      expect(map['sender_name'], 'ali');
      expect(map['receiver_name'], 'admin');
      expect(map.containsKey('image_url'), isFalse);

      const withImg = ChatMessage(
          id: 'x',
          sender: 'ali',
          receiver: 'admin',
          text: '📷 عکس',
          imageUrl: 'https://x/a.jpg',
          createdAt: '');
      expect(withImg.toMap()['image_url'], 'https://x/a.jpg');
    });
  });

  group('groupConversations', () {
    ChatMessage m(String s, String r, String t, String at) => ChatMessage(
        id: '$s$t$at', sender: s, receiver: r, text: t, createdAt: at);

    test('گروه‌بندی بر اساس طرف مقابل + جدیدترین اول', () {
      final list = [
        m('ali', 'admin', 'سلام', '2026-01-01T10:00:00'),
        m('reza', 'admin', 'قیمت؟', '2026-01-01T11:00:00'),
        m('admin', 'ali', 'علیک', '2026-01-01T12:00:00'),
      ];
      final convos = groupConversations(list, 'admin');
      expect(convos.length, 2);
      // reza جدیدتر است (11:00 > ...؟ نه — آخرین پیام ali ساعت 12 است)
      expect(convos.first.peer, 'ali');
      expect(convos.first.messages.length, 2);
      expect(convos.last.peer, 'reza');
    });

    test('پیام بدون طرف نادیده گرفته می‌شود', () {
      final convos = groupConversations(
          [m('', '', 'x', '2026-01-01T10:00:00')], 'admin');
      expect(convos, isEmpty);
    });

    test('chatOtherParty', () {
      expect(chatOtherParty(m('ali', 'admin', 'x', 't'), 'admin'), 'ali');
      expect(chatOtherParty(m('admin', 'ali', 'x', 't'), 'admin'), 'ali');
    });
  });
}
