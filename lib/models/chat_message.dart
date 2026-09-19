// پیام چت مدیر↔مشتری (خالص و تست‌پذیر).
class ChatMessage {
  final String id;
  final String sender;
  final String receiver;
  final String text;
  final String? imageUrl;
  final String createdAt;

  const ChatMessage({
    required this.id,
    required this.sender,
    required this.receiver,
    required this.text,
    this.imageUrl,
    required this.createdAt,
  });

  bool get hasImage => (imageUrl ?? '').isNotEmpty;

  factory ChatMessage.fromMap(Map<String, dynamic> m) => ChatMessage(
        id: '${m['id'] ?? ''}',
        sender: '${m['sender_name'] ?? m['sender'] ?? ''}',
        receiver: '${m['receiver_name'] ?? m['receiver'] ?? ''}',
        text: '${m['text'] ?? ''}',
        imageUrl: (m['image_url'] ?? m['imageUrl']) as String?,
        createdAt: '${m['created_at'] ?? m['createdAt'] ?? ''}',
      );

  Map<String, dynamic> toMap() => {
        'sender_name': sender,
        'receiver_name': receiver,
        'text': text,
        if (imageUrl != null && imageUrl!.isNotEmpty)
          'image_url': imageUrl,
      };
}

/// طرف مقابل من در این پیام (برای گروه‌بندی گفتگوها).
String chatOtherParty(ChatMessage m, String me) =>
    m.sender == me ? m.receiver : m.sender;

/// گروه‌بندی پیام‌ها به گفتگو (جدیدترین اول). پیام‌های بدون طرف نادیده.
List<ChatConversation> groupConversations(
    List<ChatMessage> messages, String me) {
  final map = <String, List<ChatMessage>>{};
  for (final m in messages) {
    final other = chatOtherParty(m, me);
    if (other.isEmpty) continue;
    map.putIfAbsent(other, () => []).add(m);
  }
  final list = [
    for (final e in map.entries)
      ChatConversation(peer: e.key, messages: e.value)
  ];
  list.sort((a, b) => b.last.createdAt.compareTo(a.last.createdAt));
  return list;
}

class ChatConversation {
  final String peer;
  final List<ChatMessage> messages; // قدیمی → جدید
  ChatConversation({required this.peer, required List<ChatMessage> messages})
      : messages = List.of(messages)
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  ChatMessage get last => messages.last;
}
