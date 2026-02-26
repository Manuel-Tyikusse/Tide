import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tide/core/clients/supabase_client.dart';

class CommentSheet extends StatefulWidget {
  final int postId;
  const CommentSheet({super.key, required this.postId});

  @override
  State<CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends State<CommentSheet> {
  final TextEditingController _commentController = TextEditingController();
  final List<Map<String, dynamic>> _comments = [];
  bool _isLoading = true;
  RealtimeChannel? _commentsChannel;

  @override
  void initState() {
    super.initState();
    _loadInitialComments();
    _setupRealtime();
  }

  @override
  void dispose() {
    _commentController.dispose();
    if (_commentsChannel != null) {
      print("DEBUG: Removendo RealtimeChannel para comentários do post ${widget.postId}");
      TideClient().client.removeChannel(_commentsChannel!);
    }
    super.dispose();
  }

  Future<void> _loadInitialComments() async {
    try {
      print("DEBUG: Carregando comentários iniciais para post ${widget.postId}");
      // Usando a RPC que criaste no Supabase
      final data = await TideClient().client.rpc(
        'get_comments_with_profiles',
        params: {'p_post_id': widget.postId},
      );
      
      if (mounted) {
        setState(() {
          _comments.clear();
          _comments.addAll(List<Map<String, dynamic>>.from(data));
          _isLoading = false;
        });
        print("DEBUG: ${_comments.length} comentários carregados.");
      }
    } catch (e) {
      print("DEBUG ERROR: _loadInitialComments: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _setupRealtime() {
    print("DEBUG: Configurando Realtime para post ${widget.postId}");
    _commentsChannel = TideClient()
        .client
        .channel('post_comments_${widget.postId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'comments',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'post_id',
            value: widget.postId,
          ),
          callback: (payload) {
            print("DEBUG: Novo comentário detectado via Realtime. Recarregando...");
            _loadInitialComments();
          },
        )
        .subscribe();
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final userId = TideClient().currentUserId;
    if (userId == null) return;

    try {
      print("DEBUG: Enviando novo comentário para post ${widget.postId}");
      _commentController.clear();
      // HapticFeedback para confirmar a ação ao utilizador
      HapticFeedback.lightImpact();

      await TideClient().client.from('comments').insert({
        'post_id': widget.postId,
        'user_id': userId,
        'content': text,
      });
      
    } catch (e) {
      print("DEBUG ERROR: _submitComment: $e");
      if (mounted) {
        _showSnackBar("Falha ao publicar comentário", isError: true);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12)),
        backgroundColor: isError ? Colors.redAccent : const Color(0xFF1A73E8),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(2)),
          ),
          
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              "Comentários", 
              style: GoogleFonts.inter(
                color: const Color(0xFF1F1F1F), 
                fontWeight: FontWeight.w900, 
                fontSize: 14, 
                letterSpacing: 0.5
              )
            ),
          ),
          
          const Divider(color: Color(0xFFF1F3F4), height: 1),
          
          Flexible(
            child: _isLoading 
              ? const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: Color(0xFF1A73E8), strokeWidth: 3)))
              : _comments.isEmpty 
                  ? _buildEmptyState()
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                      itemCount: _comments.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 20),
                      itemBuilder: (context, index) {
                        final comment = _comments[index];
                        
                        // Tratamento seguro do perfil (Map ou List)
                        final dynamic rawProfile = comment['profiles'];
                        final Map<String, dynamic>? profile = (rawProfile is List && rawProfile.isNotEmpty)
                            ? Map<String, dynamic>.from(rawProfile.first)
                            : (rawProfile is Map ? Map<String, dynamic>.from(rawProfile) : null);

                        final username = profile?['username'] ?? 'utilizador';
                        final avatarUrl = profile?['avatar_url'];

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: const Color(0xFFF1F3F4),
                              backgroundImage: avatarUrl != null 
                                ? NetworkImage(avatarUrl) 
                                : null,
                              child: avatarUrl == null 
                                ? const Icon(Icons.person, size: 18, color: Colors.black26) 
                                : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "@$username", 
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFF1A73E8), 
                                      fontSize: 12, 
                                      fontWeight: FontWeight.w800
                                    )
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    comment['content'] ?? '', 
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFF1F1F1F), 
                                      fontSize: 14,
                                      height: 1.4
                                    )
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
          ),

          _buildInputArea(bottomInset),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline_rounded, color: Colors.black.withOpacity(0.05), size: 64),
          const SizedBox(height: 16),
          Text(
            "Sê o primeiro a comentar!", 
            style: GoogleFonts.inter(color: Colors.black26, fontSize: 14, fontWeight: FontWeight.w600)
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea(double bottomInset) {
    return Container(
      padding: EdgeInsets.only(
        bottom: bottomInset > 0 ? bottomInset + 16 : MediaQuery.of(context).padding.bottom + 16,
        left: 20, 
        right: 12, 
        top: 12
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.black.withOpacity(0.05))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              maxLines: null,
              style: const TextStyle(color: Color(0xFF1F1F1F), fontSize: 15),
              cursorColor: const Color(0xFF1A73E8),
              decoration: InputDecoration(
                hintText: "Escreve um comentário...",
                hintStyle: const TextStyle(color: Colors.black26, fontSize: 14),
                filled: true,
                fillColor: const Color(0xFFF1F3F4),
                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24), 
                  borderSide: BorderSide.none
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _submitComment,
            icon: const Icon(Icons.send_rounded, color: Color(0xFF1A73E8), size: 28),
          )
        ],
      ),
    );
  }
}
