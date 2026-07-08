class ChatMessage {
  final String role;
  final String content;
  final String createdAt;

  const ChatMessage({required this.role, required this.content, required this.createdAt});

  Map<String, dynamic> toJson() => {'role': role, 'content': content, 'createdAt': createdAt};

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        role: json['role'] as String,
        content: json['content'] as String,
        createdAt: json['createdAt'] as String,
      );
}

class ChatSession {
  final List<ChatMessage> messages;
  final String? provider;
  final String? updatedAt;

  const ChatSession({required this.messages, this.provider, this.updatedAt});

  static const empty = ChatSession(messages: []);

  Map<String, dynamic> toJson() => {
        'messages': messages.map((m) => m.toJson()).toList(),
        'provider': provider,
        'updatedAt': updatedAt,
      };

  factory ChatSession.fromJson(Map<String, dynamic> json) => ChatSession(
        messages: (json['messages'] as List? ?? [])
            .map((m) => ChatMessage.fromJson((m as Map).cast<String, dynamic>()))
            .toList(),
        provider: json['provider'] as String?,
        updatedAt: json['updatedAt'] as String?,
      );
}

class ChatSessionSummary {
  final int contentId;
  final String? provider;
  final String? updatedAt;
  final String? lastMessage;

  const ChatSessionSummary({
    required this.contentId,
    this.provider,
    this.updatedAt,
    this.lastMessage,
  });
}
