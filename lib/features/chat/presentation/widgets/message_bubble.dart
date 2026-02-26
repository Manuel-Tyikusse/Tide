import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;

class MessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isMe;
  final bool showAvatar;
  final String? chatPartnerName;

  const MessageBubble({
    super.key, 
    required this.message, 
    required this.isMe, 
    required this.showAvatar,
    this.chatPartnerName,
  });

  @override
  Widget build(BuildContext context) {
    // Tratamento robusto para o objeto profiles (Map ou List)
    final profileData = message['profiles'];
    final profile = profileData is List ? profileData.first : profileData;
    
    final avatarUrl = profile != null ? profile['avatar_url'] : null;
    final username = profile?['username'] ?? chatPartnerName ?? 'Utilizador';
    final String content = message['content'] ?? "";
    
    // Lógica para detectar se a mensagem é uma imagem do Supabase
    final bool isImage = (content.contains('feed_media') || content.contains('chat_media')) && 
                         (content.contains('.jpg') || content.contains('.png') || content.contains('.jpeg'));

    final timestamp = DateTime.parse(message['created_at']);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 12.0),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // AVATAR DO OUTRO UTILIZADOR (ESTILO GOOGLE)
          if (!isMe)
            showAvatar 
              ? Container(
                  margin: const EdgeInsets.only(bottom: 2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black.withOpacity(0.05), width: 1),
                  ),
                  child: CircleAvatar(
                    backgroundColor: const Color(0xFFF1F3F4),
                    backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                    radius: 14,
                    child: avatarUrl == null 
                      ? const Icon(Icons.person, color: Colors.black26, size: 14) 
                      : null,
                  ),
                )
              : const SizedBox(width: 28),

          const SizedBox(width: 8),

          Flexible(
            child: Container(
              padding: isImage 
                  ? const EdgeInsets.all(4.0)
                  : const EdgeInsets.symmetric(vertical: 10.0, horizontal: 14.0),
              decoration: BoxDecoration(
                color: isMe ? const Color(0xFF1A73E8) : const Color(0xFFF1F3F4),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18),
                ),
                boxShadow: [
                  if (isMe) 
                    BoxShadow(
                      color: const Color(0xFF1A73E8).withOpacity(0.15),
                      blurRadius: 6,
                      offset: const Offset(0, 2)
                    )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // NOME DO UTILIZADOR (APENAS EM GRUPOS/RECEBIDAS)
                  if (!isMe && showAvatar)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4.0, left: 2.0),
                      child: Text(
                        username,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800, 
                          color: const Color(0xFF1A73E8), 
                          fontSize: 10,
                          letterSpacing: 0.3
                        ),
                      ),
                    ),
                  
                  // CONTEÚDO: IMAGEM OU TEXTO
                  if (isImage)
                    GestureDetector(
                      onTap: () => print("DEBUG: Abrir imagem em ecrã inteiro: $content"),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.network(
                          content,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              height: 180,
                              width: 180,
                              color: Colors.black.withOpacity(0.05),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2, 
                                  color: Color(0xFF1A73E8)
                                )
                              ),
                            );
                          },
                        ),
                      ),
                    )
                  else
                    Text(
                      content,
                      style: GoogleFonts.inter(
                        color: isMe ? Colors.white : const Color(0xFF1F1F1F), 
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.4
                      ),
                    ),
                  
                  const SizedBox(height: 4),
                  
                  // TIMESTAMP FORMATADO
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: isImage ? 4.0 : 0),
                    child: Text(
                      timeago.format(timestamp, locale: 'pt_BR_short'),
                      style: GoogleFonts.inter(
                        color: isMe ? Colors.white70 : Colors.black38,
                        fontSize: 9,
                        fontWeight: FontWeight.bold
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (isMe) const SizedBox(width: 4),
        ],
      ),
    );
  }
}
