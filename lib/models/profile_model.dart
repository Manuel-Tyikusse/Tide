import 'package:flutter/foundation.dart';

class Profile {
  final String id;
  final String username;
  final String? avatarUrl;
  final String? bio;

  Profile({
    required this.id,
    required this.username,
    this.avatarUrl,
    this.bio,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    try {
      // O ID e o Username são obrigatórios para a consistência da app
      final String id = json['id']?.toString() ?? '';
      final String username = json['username']?.toString() ?? 'Utilizador';

      if (id.isEmpty) {
        print("DEBUG WARNING: Profile.fromJson recebeu um ID vazio.");
      }

      return Profile(
        id: id,
        username: username,
        avatarUrl: json['avatar_url']?.toString(),
        bio: json['bio']?.toString(),
      );
    } catch (e, s) {
      print("DEBUG ERROR: Profile.fromJson: $e");
      debugPrintStack(stackTrace: s);
      
      // Fallback para evitar que ecrãs como o Feed bloqueiem por erro num perfil
      return Profile(
        id: json['id']?.toString() ?? '',
        username: 'Utilizador',
        bio: '',
      );
    }
  }

  /// Converte o objeto de volta para Map, útil para updates no Supabase
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'avatar_url': avatarUrl,
      'bio': bio,
    };
  }

  /// Facilita a atualização local de dados do perfil sem mutar o objeto original
  Profile copyWith({
    String? username,
    String? avatarUrl,
    String? bio,
  }) {
    return Profile(
      id: id,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
    );
  }
}