import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tide/core/clients/supabase_client.dart';
import 'package:tide/models/comment.model.dart';

class CommentsModal extends StatefulWidget {
  final int postId;
  const CommentsModal({super.key, required this.postId});

  @override
  State<CommentsModal> createState() => _CommentsModalState();
}

class _CommentsModalState extends State<CommentsModal> {
  final _client = TideClient();
  List<Comment> _comments = [];
  bool _isLoading = true;
  bool _isPosting = false;
  final _commentController = TextEditingController();

  int? _replyingToCommentId;
  String? _replyingToUsername;

  @override
  void initState() {
    super.initState();
    print("DEBUG: Abrindo modal de comentários para o post ${widget.postId}");
    _loadComments();
  }

  Future<void> _loadComments() async {
    try {
      final data = await _client.getCommentsForPost(widget.postId);
      if (mounted) {
        setState(() {
          _comments = data.map((json) => Comment.fromJson(json)).toList();
          _isLoading = false;
        });
        print("DEBUG: ${_comments.length} comentários carregados.");
      }
    } catch (e) {
      print("DEBUG ERROR: _loadComments: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _postComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _isPosting) return;

    setState(() => _isPosting = true);
    HapticFeedback.lightImpact();

    try {
      if (_replyingToCommentId != null) {
        print("DEBUG: Enviando resposta ao comentário $_replyingToCommentId");
        await _client.replyToComment(widget.postId, text, _replyingToCommentId!);
      } else {
        print("DEBUG: Enviando novo comentário de topo");
        await _client.postComment(widget.postId, text);
      }
      
      _commentController.clear();
      _cancelReply();
      await _loadComments(); 
    } catch (e) {
      print("DEBUG ERROR: _postComment: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Erro ao publicar comentário."))
        );
      }
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  void _likeUnlikeComment(Comment comment) async {
    final currentUserId = _client.currentUserId;
    if (currentUserId == null) return;

    HapticFeedback.selectionClick();
    final bool isLiked = comment.likes.any((like) => like.userId == currentUserId);

    try {
      print("DEBUG: Toggle like no comentário ${comment.id} (Atual: $isLiked)");
      if (isLiked) {
        await _client.unlikeComment(comment.id);
      } else {
        await _client.likeComment(comment.id);
      }
      _loadComments();
    } catch (e) {
      print("DEBUG ERROR: _likeUnlikeComment: $e");
    }
  }

  void _startReply(int commentId, String username) {
    setState(() {
      _replyingToCommentId = commentId;
      _replyingToUsername = username;
    });
    print("DEBUG: Iniciando resposta para @$username");
  }

  void _cancelReply() {
    setState(() {
      _replyingToCommentId = null;
      _replyingToUsername = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: _buildAppBar(),
          body: Column(
            children: [
              Expanded(
                child: _isLoading 
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF1A73E8), strokeWidth: 3))
                  : _buildCommentsList(controller),
              ),
              Padding(
                padding: EdgeInsets.only(bottom: bottomInset),
                child: _buildCommentInputField(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  AppBar _buildAppBar() => AppBar(
    title: Text("COMENTÁRIOS", 
      style: GoogleFonts.inter(
        fontWeight: FontWeight.w900, 
        fontSize: 13, 
        letterSpacing: 1.2,
        color: const Color(0xFF1F1F1F)
      )),
    centerTitle: true, 
    elevation: 0, 
    backgroundColor: Colors.white, 
    automaticallyImplyLeading: false,
    shape: Border(bottom: BorderSide(color: Colors.black.withOpacity(0.05), width: 1)),
    leading: Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    ),
  );

  Widget _buildCommentsList(ScrollController controller) {
    if (_comments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.chat_bubble_outline_rounded, color: Colors.black12, size: 48),
            const SizedBox(height: 16),
            Text("Ainda não há comentários.", 
              style: GoogleFonts.inter(color: Colors.black38, fontSize: 14, fontWeight: FontWeight.w500))
          ],
        ),
      );
    }

    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: _comments.length,
      itemBuilder: (context, index) => _buildCommentTile(_comments[index]),
    );
  }

  Widget _buildCommentTile(Comment comment, {bool isReply = false}) {
    final currentUserId = _client.currentUserId;
    final isLiked = comment.likes.any((like) => like.userId == currentUserId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(
            left: isReply ? 64 : 16, 
            right: 16, 
            top: 8, 
            bottom: 8
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start, 
            children: [
              CircleAvatar(
                radius: isReply ? 14 : 18, 
                backgroundColor: const Color(0xFFF1F3F4),
                backgroundImage: comment.author.avatarUrl != null && comment.author.avatarUrl!.isNotEmpty
                    ? NetworkImage(comment.author.avatarUrl!)
                    : null,
                child: comment.author.avatarUrl == null 
                    ? Icon(Icons.person, size: isReply ? 14 : 18, color: Colors.black26) 
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, 
                  children: [
                    RichText(
                      text: TextSpan(
                        style: GoogleFonts.inter(color: const Color(0xFF1F1F1F), fontSize: 13, height: 1.4),
                        children: [
                          TextSpan(
                            text: "${comment.author.username} ", 
                            style: const TextStyle(fontWeight: FontWeight.w800)
                          ),
                          TextSpan(
                            text: comment.content, 
                            style: const TextStyle(fontWeight: FontWeight.w400)
                          ),
                        ]
                      )
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text("1d", style: GoogleFonts.inter(color: Colors.black38, fontSize: 11, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 20),
                        GestureDetector(
                          onTap: () => _startReply(comment.id, comment.author.username), 
                          child: Text("Responder", 
                            style: GoogleFonts.inter(
                              color: Colors.black54, 
                              fontWeight: FontWeight.w800, 
                              fontSize: 11
                            )
                          )
                        ),
                      ]
                    ),
                  ]
                )
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _likeUnlikeComment(comment), 
                child: Column(
                  children: [
                    Icon(
                      isLiked ? Icons.favorite_rounded : Icons.favorite_outline_rounded, 
                      color: isLiked ? Colors.redAccent : Colors.black12, 
                      size: 16
                    ),
                    if (comment.likesCount > 0)
                      Text(
                        comment.likesCount.toString(), 
                        style: const TextStyle(color: Colors.black26, fontSize: 10, fontWeight: FontWeight.bold)
                      )
                  ],
                ),
              )
            ]
          ),
        ),
        if (comment.replies.isNotEmpty)
          ...comment.replies.map((reply) => _buildCommentTile(reply, isReply: true)),
      ],
    );
  }

  Widget _buildCommentInputField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.black.withOpacity(0.05)))
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_replyingToCommentId != null) _buildReplyingToBanner(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F3F4),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: TextField(
                    controller: _commentController,
                    maxLines: 4,
                    minLines: 1,
                    style: const TextStyle(color: Color(0xFF1F1F1F), fontSize: 14),
                    decoration: InputDecoration(
                      hintText: _replyingToUsername == null ? 'Adiciona um comentário...' : 'Responder a $_replyingToUsername...', 
                      hintStyle: const TextStyle(color: Colors.black26),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _postComment,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  child: _isPosting 
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1A73E8)))
                    : const Icon(Icons.send_rounded, color: Color(0xFF1A73E8), size: 24),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReplyingToBanner() {
    return Container(
      padding: const EdgeInsets.only(bottom: 12, left: 8, right: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween, 
        children: [
          Text("A responder a $_replyingToUsername", 
            style: const TextStyle(color: Colors.black45, fontSize: 12, fontWeight: FontWeight.w600)),
          GestureDetector(
            onTap: _cancelReply, 
            child: const Icon(Icons.close_rounded, size: 16, color: Colors.black38)
          ),
        ],
      ),
    );
  }
}
