import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/clients/supabase_client.dart';

// --- 1. MODELO DE DADOS ---
enum NotificationType { like, comment, follow, mention, reply, likeComment }

class TideNotification {
  final String id;
  final String senderId;
  final String senderUsername;
  final String? senderAvatar;
  final NotificationType type;
  final String? postThumbnail;
  final DateTime createdAt;
  final bool isRead;

  TideNotification({
    required this.id,
    required this.senderId,
    required this.senderUsername,
    this.senderAvatar,
    required this.type,
    this.postThumbnail,
    required this.createdAt,
    this.isRead = false,
  });
}

// --- 2. SERVIÇO DE NOTIFICAÇÕES ---
class NotificationService {
  final TideClient _tide = TideClient();

  Future<List<TideNotification>> fetchNotifications() async {
    final userId = _tide.currentUserId;
    if (userId == null) return [];

    try {
      print("DEBUG: Procurando notificações para o utilizador: $userId");
      final response = await _tide.client
          .from('notifications')
          .select('''
            id, 
            type, 
            created_at, 
            is_read,
            sender_id,
            sender:profiles!notifications_sender_id_fkey(username, avatar_url),
            post:posts!notifications_post_id_fkey(media_url)
          ''')
          .eq('receiver_id', userId)
          .order('created_at', ascending: false)
          .limit(50);

      final List<TideNotification> notifications = (response as List).map((json) {
        final sender = json['sender'] as Map<String, dynamic>?;
        final post = json['post'] as Map<String, dynamic>?;

        return TideNotification(
          id: json['id'].toString(),
          senderId: json['sender_id'].toString(),
          senderUsername: sender?['username'] ?? 'utilizador',
          senderAvatar: sender?['avatar_url'],
          type: _parseType(json['type']),
          postThumbnail: post?['media_url'],
          createdAt: DateTime.parse(json['created_at']).toLocal(),
          isRead: json['is_read'] ?? false,
        );
      }).toList();

      print("DEBUG: ${notifications.length} notificações carregadas.");
      return notifications;
    } catch (e) {
      print("DEBUG ERROR: fetchNotifications: $e");
      return [];
    }
  }

  NotificationType _parseType(String? type) {
    switch (type) {
      case 'like': return NotificationType.like;
      case 'comment': return NotificationType.comment;
      case 'follow': return NotificationType.follow;
      case 'mention': return NotificationType.mention;
      case 'reply_comment': return NotificationType.reply;
      case 'like_comment': return NotificationType.likeComment;
      default: return NotificationType.like;
    }
  }

  Future<void> markAllAsRead() async {
    final userId = _tide.currentUserId;
    if (userId == null) return;
    try {
      print("DEBUG: Marcando todas as notificações como lidas para: $userId");
      await _tide.client
          .from('notifications')
          .update({'is_read': true})
          .eq('receiver_id', userId)
          .eq('is_read', false);
    } catch (e) {
      print("DEBUG ERROR: markAllAsRead: $e");
    }
  }
}

// --- 3. INTERFACE DE UTILIZADOR (UI) ---
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _service = NotificationService();
  final TideClient _tide = TideClient();
  bool _isLoading = true;
  List<TideNotification> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final data = await _service.fetchNotifications();
    if (mounted) {
      setState(() {
        _notifications = data;
        _isLoading = false;
      });
      if (data.any((n) => !n.isRead)) {
        await _service.markAllAsRead();
      }
    }
  }

  String _getMsg(NotificationType type) {
    switch (type) {
      case NotificationType.like: return "curtiu a tua publicação.";
      case NotificationType.comment: return "comentou na tua publicação.";
      case NotificationType.follow: return "começou a seguir-te.";
      case NotificationType.mention: return "mencionou-te numa publicação.";
      case NotificationType.reply: return "respondeu ao teu comentário.";
      case NotificationType.likeComment: return "curtiu o teu comentário.";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        title: Text(
          "Atividade", 
          style: GoogleFonts.inter(
            color: const Color(0xFF1F1F1F),
            fontWeight: FontWeight.w900, 
            fontSize: 24, 
            letterSpacing: -0.5
          )
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(color: Colors.black.withOpacity(0.05), height: 1),
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF1A73E8), strokeWidth: 3))
        : RefreshIndicator(
            onRefresh: _loadData,
            color: const Color(0xFF1A73E8),
            backgroundColor: Colors.white,
            child: _notifications.isEmpty 
              ? _buildEmptyState()
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _notifications.length,
                  separatorBuilder: (context, index) => Divider(
                    color: Colors.black.withOpacity(0.03), 
                    indent: 74, 
                    endIndent: 16,
                  ),
                  itemBuilder: (context, index) => _buildItem(_notifications[index]),
                ),
          ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F3F4),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.notifications_none_rounded, color: Colors.black12, size: 64),
          ),
          const SizedBox(height: 24),
          Text(
            "Tudo em dia!",
            style: GoogleFonts.inter(
              color: const Color(0xFF1F1F1F), 
              fontWeight: FontWeight.w800,
              fontSize: 16
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Novas interações aparecerão aqui.",
            style: GoogleFonts.inter(color: Colors.black38, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(TideNotification item) {
    return Material(
      color: item.isRead ? Colors.transparent : const Color(0xFF1A73E8).withOpacity(0.04),
      child: InkWell(
        onTap: () {
          print("DEBUG: Navegando para origem da notificação ID: ${item.id}");
          HapticFeedback.lightImpact();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // AVATAR
              GestureDetector(
                onTap: () => print("DEBUG: Abrir perfil de ${item.senderId}"),
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFFF1F3F4),
                  backgroundImage: item.senderAvatar != null ? NetworkImage(item.senderAvatar!) : null,
                  child: item.senderAvatar == null 
                    ? const Icon(Icons.person, color: Colors.black26, size: 22) 
                    : null,
                ),
              ),
              const SizedBox(width: 14),
              
              // TEXTO
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: GoogleFonts.inter(color: const Color(0xFF1F1F1F), fontSize: 14, height: 1.3),
                        children: [
                          TextSpan(
                            text: item.senderUsername, 
                            style: const TextStyle(fontWeight: FontWeight.w800)
                          ),
                          TextSpan(
                            text: " ${_getMsg(item.type)}",
                            style: const TextStyle(fontWeight: FontWeight.w400)
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      timeago.format(item.createdAt, locale: 'pt_BR_short'),
                      style: GoogleFonts.inter(
                        color: Colors.black38, 
                        fontSize: 12, 
                        fontWeight: FontWeight.w600
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(width: 12),
              
              // TRAILING (BUTTON OU THUMBNAIL)
              _buildTrailing(item),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrailing(TideNotification item) {
    if (item.type == NotificationType.follow) {
      return ElevatedButton(
        onPressed: () async {
          print("DEBUG: Follow back para ${item.senderId}");
          await _tide.followUser(item.senderId);
          _loadData();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1A73E8),
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(80, 32),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        child: Text(
          "Seguir", 
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800)
        ),
      );
    }
    
    if (item.postThumbnail != null) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.black.withOpacity(0.05)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: Image.network(
            item.postThumbnail!, 
            width: 48, 
            height: 48, 
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(color: const Color(0xFFF1F3F4), width: 48, height: 48),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}