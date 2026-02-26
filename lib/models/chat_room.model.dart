import 'package:flutter/foundation.dart' show debugPrint;

class ChatRoom {
  final String roomId;
  final bool isGroup;
  final String? displayName;
  final String? displayAvatarUrl;
  final LastMessage? lastMessage;
  final int unreadCount;

  ChatRoom({
    required this.roomId,
    required this.isGroup,
    this.displayName,
    this.displayAvatarUrl,
    this.lastMessage,
    required this.unreadCount,
  });

  factory ChatRoom.fromJson(Map<String, dynamic> json) {
    try {
      final lastMessageData = json['last_message'];
      
      return ChatRoom(
        roomId: json['room_id']?.toString() ?? '',
        isGroup: json['is_group'] ?? false,
        displayName: json['display_name'] as String?,
        displayAvatarUrl: json['display_avatar_url'] as String?,
        lastMessage: (lastMessageData != null && lastMessageData is Map<String, dynamic>) 
            ? LastMessage.fromJson(lastMessageData) 
            : null,
        unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
      );
    } catch (e, s) {
      debugPrint('DEBUG ERROR: ChatRoom.fromJson: $e');
      debugPrint('STACK TRACE: $s');
      
      // Fallback para manter a UI estável mesmo com dados corrompidos
      return ChatRoom(
        roomId: json['room_id']?.toString() ?? 'unknown', 
        isGroup: false, 
        unreadCount: 0,
        displayName: 'Conversa',
      );
    }
  }

  /// Cria uma cópia da instância atualizando apenas campos específicos.
  /// Ideal para atualizações em tempo real via WebSockets/Supabase Realtime.
  ChatRoom copyWith({
    LastMessage? lastMessage,
    int? unreadCount,
    String? displayName,
    String? displayAvatarUrl,
  }) {
    return ChatRoom(
      roomId: roomId,
      isGroup: isGroup,
      displayName: displayName ?? this.displayName,
      displayAvatarUrl: displayAvatarUrl ?? this.displayAvatarUrl,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}

class LastMessage {
  final String content;
  final DateTime createdAt;
  final String senderId;

  LastMessage({
    required this.content,
    required this.createdAt,
    required this.senderId,
  });

  factory LastMessage.fromJson(Map<String, dynamic> json) {
    try {
      return LastMessage(
        content: json['content']?.toString() ?? '',
        createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
        senderId: json['sender_id']?.toString() ?? '',
      );
    } catch (e) {
      debugPrint('DEBUG ERROR: LastMessage.fromJson: $e');
      return LastMessage(
        content: '',
        createdAt: DateTime.now(),
        senderId: '',
      );
    }
  }
}
