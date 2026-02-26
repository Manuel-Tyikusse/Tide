import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:tide/core/clients/supabase_client.dart';

class ChatListTile extends StatelessWidget {
  final Map<String, dynamic> chatRoom;
  final VoidCallback onTap;

  const ChatListTile({super.key, required this.chatRoom, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final client = TideClient();
    final currentUserId = client.currentUserId;

    // 1. Extrair metadados da sala
    final isGroup = chatRoom['is_group'] as bool? ?? false;
    final lastMessage = chatRoom['last_message'] as String?;
    final lastMessageTimestamp = chatRoom['last_message_time'] as String?;
    final unreadCount = chatRoom['unread_count'] as int? ?? 0;
    
    // 2. Lógica para definir Título e Avatar
    String title = 'Conversa';
    String? avatarUrl;

    if (isGroup) {
      title = chatRoom['group_name'] ?? 'Tide Group';
      avatarUrl = chatRoom['avatar_url'];
    } else {
      final participants = chatRoom['chat_participants'] as List? ?? [];
      try {
        final otherParticipant = participants.firstWhere(
          (p) => p['profiles']['id'] != currentUserId,
          orElse: () => participants.first,
        );
        final profile = otherParticipant['profiles'];
        title = profile['username'] ?? 'Utilizador';
        avatarUrl = profile['avatar_url'];
      } catch (e) {
        print("DEBUG ERROR: ChatListTile Profile: $e");
        title = 'Utilizador Tide';
      }
    }

    return Material(
      color: Colors.transparent,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        leading: Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: unreadCount > 0 ? const Color(0xFF1A73E8) : Colors.black.withOpacity(0.05), 
              width: 1.5
            ),
          ),
          child: CircleAvatar(
            radius: 28,
            backgroundColor: const Color(0xFFF1F3F4), // Cinza-azulado Google
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
            child: avatarUrl == null
                ? Icon(
                    isGroup ? Icons.groups_rounded : Icons.person_rounded, 
                    color: Colors.black26, 
                    size: 28
                  )
                : null,
          ),
        ),
        title: Text(
          title,
          style: GoogleFonts.inter(
            fontWeight: unreadCount > 0 ? FontWeight.w800 : FontWeight.w600, 
            color: const Color(0xFF1F1F1F),
            fontSize: 15
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            lastMessage ?? (isGroup ? 'Ver grupo' : 'Inicia uma conversa'),
            style: GoogleFonts.inter(
              color: unreadCount > 0 ? Colors.black87 : Colors.black38,
              fontSize: 13,
              fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.normal
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (lastMessageTimestamp != null)
              Text(
                _formatTime(lastMessageTimestamp),
                style: GoogleFonts.inter(
                  fontSize: 11, 
                  color: unreadCount > 0 ? const Color(0xFF1A73E8) : Colors.black26, 
                  fontWeight: unreadCount > 0 ? FontWeight.w900 : FontWeight.bold
                ),
              ),
            const SizedBox(height: 8),
            if (unreadCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A73E8), 
                  borderRadius: BorderRadius.circular(12)
                ),
                child: Text(
                  unreadCount.toString(),
                  style: const TextStyle(
                    color: Colors.white, 
                    fontSize: 10, 
                    fontWeight: FontWeight.w900
                  ),
                ),
              )
            else
              const SizedBox(height: 18), // Spacer para manter alinhamento
          ],
        ),
      ),
    );
  }

  String _formatTime(String timestamp) {
    try {
      final date = DateTime.parse(timestamp).toLocal();
      // 'en_short' para minimalismo: 5m, 1h, 2d
      return timeago.format(date, locale: 'en_short'); 
    } catch (e) {
      return '';
    }
  }
}
