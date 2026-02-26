import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tide/core/clients/supabase_client.dart';
import 'package:tide/features/posts/presentation/widgets/comment_tile.dart';
import 'package:timeago/timeago.dart' as timeago;

class PostDetailScreen extends StatefulWidget {
  final Map<String, dynamic> post;

  const PostDetailScreen({super.key, required this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  List<Map<String, dynamic>> _comments = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  int _currentImageIndex = 0;
  final TextEditingController _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    print("DEBUG: Inicializando PostDetailScreen para post ${widget.post['id']}");
    timeago.setLocaleMessages('pt', timeago.PtBrMessages());
    _fetchComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _fetchComments() async {
    try {
      print("DEBUG: Buscando comentários via Supabase...");
      
      // 1. Fazemos a busca. 
      // Nota: O profiles(...) sem o alias 'author' costuma ser mais estável se não houver múltiplas chaves estrangeiras.
      final response = await TideClient().client
          .from('comments')
          .select('*, profiles(username, avatar_url)') 
          .eq('post_id', widget.post['id'])
          .order('created_at', ascending: true);

      final rawData = response as List<dynamic>;

      if (mounted) {
        final List<Map<String, dynamic>> processedComments = [];

        for (var item in rawData) {
          final comment = Map<String, dynamic>.from(item as Map);
          
          // 2. EXTRAÇÃO DIRETA: Pegamos o username de dentro do objeto profiles
          final profileData = comment['profiles'] as Map<String, dynamic>?;
          
          // 3. O PULO DO GATO: Criamos a chave 'display_name' diretamente no comentário
          // Se o perfil não existir por algum motivo, ele mostra 'Utilizador'
          comment['display_name'] = profileData?['username'] ?? 'Utilizador';
          comment['display_avatar'] = profileData?['avatar_url'];

          processedComments.add(comment);
        }

        setState(() {
          _comments = processedComments;
          _isLoading = false;
        });
        print("DEBUG: ${_comments.length} comentários processados com nomes diretos.");
      }
    } catch (e) {
      print("DEBUG ERROR: _fetchComments: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    final userId = TideClient().currentUserId;
    
    if (text.isEmpty || userId == null || _isSubmitting) return;

    setState(() => _isSubmitting = true);
    HapticFeedback.mediumImpact();

    try {
      print("DEBUG: Inserindo novo comentário...");
      await TideClient().client.from('comments').insert({
        'post_id': widget.post['id'],
        'user_id': userId,
        'content': text,
      });
      
      _commentController.clear();
      if (mounted) {
        FocusScope.of(context).unfocus();
        await _fetchComments();
      }
    } catch (e) {
      print("DEBUG ERROR: _submitComment: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao publicar comentário.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _handleDeletePost() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Eliminar publicação?', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
        content: const Text('Esta ação não pode ser desfeita e removerá permanentemente o post.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), 
            child: Text('CANCELAR', style: GoogleFonts.inter(color: Colors.black38, fontWeight: FontWeight.bold))
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('ELIMINAR', style: GoogleFonts.inter(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        print("DEBUG: Eliminando post ${widget.post['id']}");
        await TideClient().client.from('posts').delete().eq('id', widget.post['id']);
        if (mounted) Navigator.of(context).pop();
      } catch (e) {
        print("DEBUG ERROR: _handleDeletePost: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final postAuthor = widget.post['profiles'] as Map<String, dynamic>?;
    final isMyPost = widget.post['user_id'] == TideClient().currentUserId;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          "PUBLICAÇÃO", 
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.black)
        ),
        actions: [
          if (isMyPost)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
              onPressed: _handleDeletePost,
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(color: Colors.black.withOpacity(0.05), height: 1),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchComments,
              color: const Color(0xFF1A73E8),
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _buildPostContent(postAuthor)),
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text("Comentários", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                    ),
                  ),
                  if (_isLoading)
                    const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: Color(0xFF1A73E8), strokeWidth: 2)))
                  else if (_comments.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: Text("Ainda sem comentários.", style: GoogleFonts.inter(color: Colors.black26, fontSize: 13))),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => CommentTile(comment: _comments[index]),
                        childCount: _comments.length,
                      ),
                    ),
                ],
              ),
            ),
          ),
          _buildCommentInput(),
        ],
      ),
    );
  }

  Widget _buildPostContent(Map<String, dynamic>? author) {
    final List<dynamic> gallery = widget.post['media_gallery'] ?? [];
    final bool hasGallery = gallery.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasGallery)
          _buildCarousel(gallery)
        else if (widget.post['media_url'] != null)
          Container(
            color: const Color(0xFFF8F9FA),
            constraints: const BoxConstraints(maxHeight: 500),
            width: double.infinity,
            child: Image.network(widget.post['media_url'], fit: BoxFit.cover),
          ),

        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundImage: author?['avatar_url'] != null ? NetworkImage(author!['avatar_url']) : null,
                    backgroundColor: const Color(0xFFF1F3F4),
                    child: author?['avatar_url'] == null ? const Icon(Icons.person, size: 16, color: Colors.black26) : null,
                  ),
                  const SizedBox(width: 10),
                  Text(author?['username'] ?? 'utilizador', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                widget.post['caption'] ?? '', 
                style: const TextStyle(color: Color(0xFF1F1F1F), fontSize: 15, height: 1.5)
              ),
              const SizedBox(height: 12),
              Text(
                timeago.format(DateTime.parse(widget.post['created_at']), locale: 'pt').toUpperCase(),
                style: GoogleFonts.inter(color: Colors.black38, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5),
              ),
            ],
          ),
        ),
        Divider(color: Colors.black.withOpacity(0.05), height: 1),
      ],
    );
  }

  Widget _buildCarousel(List<dynamic> gallery) {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        SizedBox(
          height: 400,
          width: double.infinity,
          child: PageView.builder(
            itemCount: gallery.length,
            onPageChanged: (index) => setState(() => _currentImageIndex = index),
            itemBuilder: (context, index) => Image.network(gallery[index], fit: BoxFit.cover),
          ),
        ),
        if (gallery.length > 1)
          Positioned(
            bottom: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: List.generate(gallery.length, (index) => Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentImageIndex == index ? Colors.white : Colors.white.withOpacity(0.4),
                  ),
                )),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCommentInput() {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 12,
        left: 16, right: 8, top: 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.black.withOpacity(0.05))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              decoration: InputDecoration(
                hintText: 'Adiciona um comentário...',
                hintStyle: const TextStyle(color: Colors.black26, fontSize: 14),
                filled: true,
                fillColor: const Color(0xFFF1F3F4),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              style: const TextStyle(fontSize: 14),
              maxLines: 4,
              minLines: 1,
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: _isSubmitting 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1A73E8)))
                : const Icon(Icons.send_rounded, color: Color(0xFF1A73E8)),
            onPressed: _submitComment,
          ),
        ],
      ),
    );
  }
}