import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../profile/presentation/screens/profile_screen.dart';

class CommentTile extends StatelessWidget {
  final Map<String, dynamic> comment;

  const CommentTile({super.key, required this.comment});

  @override
  Widget build(BuildContext context) {
    // EXTRAÇÃO DE DADOS: Prioriza as chaves injetadas pelo _fetchComments
    // Fallback para 'author' (TideClient antigo) ou 'profiles' (Join direto do Supabase)
    final String username = comment['display_name'] ?? 
                            (comment['author'] as Map?)?['username'] ?? 
                            (comment['profiles'] as Map?)?['username'] ??
                            'utilizador';
                            
    final String? avatarUrl = comment['display_avatar'] ?? 
                              (comment['author'] as Map?)?['avatar_url'] ??
                              (comment['profiles'] as Map?)?['avatar_url'];
                              
    final String content = comment['content'] ?? '';
    
    // O ID do usuário para navegação (essencial para o clique no avatar/nome)
    final String userId = comment['user_id'] ?? 
                          (comment['author'] as Map?)?['id'] ?? 
                          ''; 
    
    final DateTime createdAt = comment['created_at'] != null 
        ? DateTime.parse(comment['created_at']).toLocal()
        : DateTime.now();

    void navigateToProfile() {
      if (userId.isEmpty) {
        print("DEBUG WARNING: Impossível navegar. ID do utilizador está vazio para o comentário: ${comment['id']}");
        return;
      }
      print("DEBUG: Navegando para o perfil do autor do comentário: $userId ($username)");
      HapticFeedback.selectionClick();
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ProfileScreen(userId: userId)),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar clicável
          GestureDetector(
            onTap: navigateToProfile,
            child: CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFFF1F3F4),
              backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty) 
                  ? NetworkImage(avatarUrl) 
                  : null,
              child: (avatarUrl == null || avatarUrl.isEmpty) 
                  ? const Icon(Icons.person, size: 18, color: Colors.black26) 
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          
          // Conteúdo do Comentário
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: navigateToProfile, // Permite clicar no nome também
                  child: RichText(
                    text: TextSpan(
                      style: GoogleFonts.inter(fontSize: 14, height: 1.4, color: const Color(0xFF1F1F1F)),
                      children: [
                        TextSpan(
                          text: "$username ",
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
                          ),
                        ),
                        TextSpan(
                          text: content,
                          style: const TextStyle(
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                
                // Ações e Tempo
                Row(
                  children: [
                    Text(
                      timeago.format(createdAt, locale: 'pt_BR_short'),
                      style: GoogleFonts.inter(
                        color: Colors.black38, 
                        fontSize: 11, 
                        fontWeight: FontWeight.w600
                      ),
                    ),
                    const SizedBox(width: 24),
                    GestureDetector(
                      onTap: () {
                        print("DEBUG: Iniciar fluxo de resposta para o comentário ID: ${comment['id']}");
                        HapticFeedback.lightImpact();
                      },
                      child: Text(
                        'Responder',
                        style: GoogleFonts.inter(
                          color: Colors.black45, 
                          fontSize: 11, 
                          fontWeight: FontWeight.w800
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Like do Comentário
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              children: [
                GestureDetector(
                  onTap: () {
                    print("DEBUG: Toggle Like no comentário ID: ${comment['id']}");
                    HapticFeedback.mediumImpact();
                  },
                  child: const Icon(
                    Icons.favorite_outline_rounded, 
                    size: 16, 
                    color: Colors.black26
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  '0', 
                  style: TextStyle(color: Colors.black26, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}