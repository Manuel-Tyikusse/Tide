import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../posts/presentation/screens/post_detail_screen.dart';
import '../../../profile/presentation/screens/profile_screen.dart';

class NotificationTile extends StatelessWidget {
  final Map<String, dynamic> notification;

  const NotificationTile({super.key, required this.notification});

  void _handleNavigation(BuildContext context) {
    final type = notification['type'];
    final postData = notification['posts'];
    final senderProfile = notification['sender'];

    print("DEBUG: Navegando a partir da notificação tipo: $type");
    HapticFeedback.lightImpact();

    // Navega para o post se for uma interação de conteúdo
    if ((type == 'like' || type == 'comment' || type == 'reply_comment' || type == 'like_comment') && postData != null) {
      print("DEBUG: Redirecionando para PostDetailScreen (ID: ${postData['id']})");
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => PostDetailScreen(post: postData),
      ));
    } 
    // Caso contrário, vai para o perfil do remetente
    else if (senderProfile != null) {
      print("DEBUG: Redirecionando para ProfileScreen (UserID: ${senderProfile['id']})");
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => ProfileScreen(userId: senderProfile['id']),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final senderProfile = notification['sender'] as Map<String, dynamic>?;
    final postData = notification['posts'] as Map<String, dynamic>?;
    final type = notification['type'] as String? ?? 'unknown';
    final bool isRead = notification['is_read'] ?? true;
    
    if (senderProfile == null) {
      print("DEBUG WARNING: NotificationTile recebeu senderProfile nulo.");
      return const SizedBox.shrink();
    }

    return InkWell(
      onTap: () => _handleNavigation(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          // Fundo azul extremamente subtil para notificações não lidas
          color: isRead ? Colors.transparent : const Color(0xFF1A73E8).withOpacity(0.04),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildAvatar(context, senderProfile['avatar_url'], senderProfile['id']),
            const SizedBox(width: 14),
            Expanded(
              child: _buildNotificationText(senderProfile['username'] ?? 'Alguém', type),
            ),
            _buildTrailing(type, postData, isRead),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(BuildContext context, String? url, String userId) {
    return GestureDetector(
      onTap: () {
        print("DEBUG: Avatar clicado, navegando para perfil: $userId");
        HapticFeedback.selectionClick();
        Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: userId)));
      },
      child: Container(
        padding: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black.withOpacity(0.05), width: 1),
        ),
        child: CircleAvatar(
          radius: 22,
          backgroundColor: const Color(0xFFF1F3F4),
          backgroundImage: url != null && url.isNotEmpty ? NetworkImage(url) : null,
          child: (url == null || url.isEmpty) ? const Icon(Icons.person, color: Colors.black26, size: 20) : null,
        ),
      ),
    );
  }

  Widget _buildNotificationText(String username, String type) {
    return RichText(
      text: TextSpan(
        style: GoogleFonts.inter(color: const Color(0xFF1F1F1F), fontSize: 13, height: 1.4),
        children: [
          TextSpan(text: username, style: const TextStyle(fontWeight: FontWeight.w800)),
          TextSpan(text: ' ${_getMessage(type)}'),
          TextSpan(
            text: '  •  ${_timeAgo(notification['created_at'])}',
            style: GoogleFonts.inter(color: Colors.black38, fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildTrailing(String type, Map<String, dynamic>? post, bool isRead) {
    final thumbnailUrl = post?['thumbnail_url'] ?? post?['media_url'];
    final contentTypes = ['like', 'comment', 'reply_comment', 'like_comment', 'mention'];

    if (contentTypes.contains(type) && thumbnailUrl != null) {
      return Container(
        width: 44,
        height: 44,
        margin: const EdgeInsets.only(left: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: const Color(0xFFF1F3F4),
          border: Border.all(color: Colors.black.withOpacity(0.05)),
          image: DecorationImage(
            image: NetworkImage(thumbnailUrl),
            fit: BoxFit.cover,
          ),
        ),
      );
    }
    
    // Ponto indicador azul para "não lido" em notificações de sistema/follow
    if (!isRead) {
      return Container(
        width: 8,
        height: 8,
        margin: const EdgeInsets.only(left: 12),
        decoration: const BoxDecoration(
          color: Color(0xFF1A73E8), 
          shape: BoxShape.circle
        ),
      );
    }

    return const SizedBox.shrink();
  }

  String _getMessage(String type) {
    switch (type) {
      case 'follow':
      case 'new_follower': return 'começou a seguir-te.';
      case 'like': return 'gostou da tua publicação.';
      case 'comment': return 'comentou na tua publicação.';
      case 'reply_comment': return 'respondeu ao teu comentário.';
      case 'like_comment': return 'curtiu o teu comentário.';
      case 'mention': return 'mencionou-te numa publicação.';
      default: return 'interagiu contigo.';
    }
  }

  String _timeAgo(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final diff = DateTime.now().difference(date);
      if (diff.inDays > 7) return '${(diff.inDays / 7).floor()}sem';
      if (diff.inDays > 0) return '${diff.inDays}d';
      if (diff.inHours > 0) return '${diff.inHours}h';
      if (diff.inMinutes > 0) return '${diff.inMinutes}min';
      return 'agora';
    } catch (e) { 
      print("DEBUG ERROR: _timeAgo falhou para data $dateStr: $e");
      return ''; 
    }
  }
}