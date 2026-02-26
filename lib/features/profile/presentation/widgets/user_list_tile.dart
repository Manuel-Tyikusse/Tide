import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tide/core/clients/supabase_client.dart';
import '../screens/profile_screen.dart';

class UserListTile extends StatelessWidget {
  final Map<String, dynamic> user;
  final Widget? trailing; 

  const UserListTile({
    super.key, 
    required this.user, 
    this.trailing, 
  });

  @override
  Widget build(BuildContext context) {
    final String? avatarUrl = user['avatar_url'];
    final String username = user['username'] ?? 'Utilizador';
    final String? bio = user['bio'];
    final String userId = user['id'] ?? '';
    final String? myId = TideClient().currentUserId;

    return ListTile(
      onTap: () {
        print("DEBUG: UserListTile clicado. Navegando para o perfil: $userId ($username)");
        HapticFeedback.selectionClick();
        if (userId.isEmpty) {
          print("DEBUG WARNING: ID do utilizador está vazio. Navegação cancelada.");
          return;
        }
        
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProfileScreen(userId: userId),
          ),
        );
      },
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black.withOpacity(0.05), width: 1),
        ),
        child: CircleAvatar(
          radius: 22,
          backgroundColor: const Color(0xFFF1F3F4),
          backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty) 
              ? NetworkImage(avatarUrl)
              : null,
          child: (avatarUrl == null || avatarUrl.isEmpty)
              ? const Icon(Icons.person_rounded, color: Colors.black12, size: 20)
              : null,
        ),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              username,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: const Color(0xFF1F1F1F), 
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          if (userId == myId) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F0FE), // Azul Google muito claro
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                "TU",
                style: GoogleFonts.inter(
                  color: const Color(0xFF1A73E8),
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: bio != null && bio.isNotEmpty
          ? Text(
              bio,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: Colors.black45, 
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            )
          : null,
      trailing: trailing ?? const Icon(
        Icons.arrow_forward_ios_rounded, 
        color: Colors.black12, 
        size: 14,
      ),
    );
  }
}
