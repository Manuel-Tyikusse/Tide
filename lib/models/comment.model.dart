import 'package:flutter/foundation.dart';
import 'package:tide/models/profile_model.dart';

class CommentLike {
  final String userId;
  CommentLike({required this.userId});

  factory CommentLike.fromJson(Map<String, dynamic> json) {
    return CommentLike(userId: json['user_id']?.toString() ?? '');
  }
}

class Comment {
  final int id;
  final String content;
  final DateTime createdAt;
  final int likesCount;
  final Profile author;
  final List<CommentLike> likes;
  final List<Comment> replies;

  Comment({
    required this.id,
    required this.content,
    required this.createdAt,
    required this.likesCount,
    required this.author,
    required this.likes,
    required this.replies,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    try {
      // Parsing de respostas (recursivo)
      var repliesFromJson = json['replies'] as List? ?? [];
      List<Comment> replyList = repliesFromJson
          .map((i) => Comment.fromJson(Map<String, dynamic>.from(i)))
          .toList();

      // Parsing de likes específicos do comentário
      var likesFromJson = json['comment_likes'] as List? ?? [];
      List<CommentLike> likeList = likesFromJson
          .map((i) => CommentLike.fromJson(Map<String, dynamic>.from(i)))
          .toList();

      return Comment(
        id: json['id'] as int? ?? 0,
        content: json['content']?.toString() ?? '',
        createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
        likesCount: (json['likes_count'] as num?)?.toInt() ?? 0,
        author: Profile.fromJson(json['profiles'] ?? {}),
        likes: likeList,
        replies: replyList,
      );
    } catch (e, s) {
      debugPrint('DEBUG ERROR: Comment.fromJson: $e');
      debugPrint('STACK TRACE: $s');
      
      // Fallback para evitar falha na árvore de comentários
      return Comment(
        id: -1,
        content: 'Erro ao carregar comentário',
        createdAt: DateTime.now(),
        likesCount: 0,
        author: Profile(id: '', username: 'Utilizador'), // Fallback de autor
        likes: [],
        replies: [],
      );
    }
  }

  /// Método útil para atualizar o estado local do comentário (ex: toggle like)
  Comment copyWith({
    int? likesCount,
    List<CommentLike>? likes,
    List<Comment>? replies,
  }) {
    return Comment(
      id: id,
      content: content,
      createdAt: createdAt,
      likesCount: likesCount ?? this.likesCount,
      author: author,
      likes: likes ?? this.likes,
      replies: replies ?? this.replies,
    );
  }
}
