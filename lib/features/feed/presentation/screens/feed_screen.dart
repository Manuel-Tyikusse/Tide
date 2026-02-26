import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/services/algorithm_service.dart';
import '../widgets/image_post_item.dart';
import '../widgets/video_player_item.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final PageController _pageController = PageController();
  final List<Map<String, dynamic>> _posts = [];
  
  bool _isLoading = true;
  bool _isFetchingMore = false;
  bool _hasMore = true;
  int _currentOffset = 0;
  final int _limit = 10;

  @override
  void initState() {
    super.initState();
    _loadInitialFeed();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialFeed() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      print("DEBUG: Iniciando carregamento do feed ranqueado (Offset: 0)");
      final posts = await AlgorithmService().getRankedFeed(limit: _limit, offset: 0);
      
      if (mounted) {
        setState(() {
          _posts.clear();
          _posts.addAll(posts);
          _currentOffset = posts.length;
          _hasMore = posts.length >= _limit;
          _isLoading = false;
        });
        print("DEBUG: Feed inicial carregado com sucesso. Total: ${_posts.length}");
      }
    } catch (e) {
      print("DEBUG ERROR: AlgorithmService (Initial): $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchMorePosts() async {
    if (_isFetchingMore || !_hasMore) return;

    setState(() => _isFetchingMore = true);
    print("DEBUG: Carregando mais posts (Offset: $_currentOffset)");
    
    try {
      final newPosts = await AlgorithmService().getRankedFeed(
        limit: _limit, 
        offset: _currentOffset
      );

      if (mounted) {
        setState(() {
          if (newPosts.isEmpty) {
            _hasMore = false;
            print("DEBUG: Fim do feed alcançado.");
          } else {
            _posts.addAll(newPosts);
            _currentOffset += newPosts.length;
            _hasMore = newPosts.length >= _limit;
            print("DEBUG: Mais ${newPosts.length} posts adicionados.");
          }
          _isFetchingMore = false;
        });
      }
    } catch (e) {
      print("DEBUG ERROR: AlgorithmService (More): $e");
      if (mounted) setState(() => _isFetchingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF1F3F4),
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF1A73E8), 
            strokeWidth: 3
          )
        ),
      );
    }

    if (_posts.isEmpty) {
      return _buildEmptyState();
    }

    return Scaffold(
      backgroundColor: Colors.black, // Mantemos preto para o vídeo/imagem ter imersão total
      extendBodyBehindAppBar: true,
      body: RefreshIndicator(
        onRefresh: _loadInitialFeed,
        color: const Color(0xFF1A73E8),
        backgroundColor: Colors.white,
        strokeWidth: 3,
        child: PageView.builder(
          controller: _pageController,
          scrollDirection: Axis.vertical,
          itemCount: _posts.length + (_hasMore ? 1 : 0),
          onPageChanged: (index) {
            if (index >= _posts.length - 2) {
              _fetchMorePosts();
            }
            
            if (index < _posts.length) {
              print("DEBUG: Tracking view para post_id: ${_posts[index]['id']}");
              AlgorithmService().updateEngagement(_posts[index]['id'], isView: true);
            }
          },
          itemBuilder: (context, index) {
            if (index == _posts.length) {
              return Container(
                color: Colors.black,
                child: const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(color: Colors.white24, strokeWidth: 2),
                  ),
                ),
              );
            }

            final post = _posts[index];
            final mediaType = post['media_type'];

            return _FeedItemWrapper(
              key: ValueKey(post['id']),
              child: mediaType == 'image'
                  ? ImagePostItem(post: post)
                  : VideoPlayerItem(post: post),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F3F4),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome_motion_rounded, color: Colors.black12, size: 64),
            ),
            const SizedBox(height: 32),
            Text(
              "SEM PUBLICAÇÕES NOVAS",
              style: GoogleFonts.inter(
                color: const Color(0xFF1F1F1F), 
                fontWeight: FontWeight.w900, 
                fontSize: 14,
                letterSpacing: 1.5
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "O teu feed está atualizado por agora.",
              style: GoogleFonts.inter(color: Colors.black38, fontSize: 13),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _loadInitialFeed,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A73E8),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                elevation: 0,
              ),
              child: Text("RECARREGAR", style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedItemWrapper extends StatefulWidget {
  final Widget child;
  const _FeedItemWrapper({super.key, required this.child});

  @override
  State<_FeedItemWrapper> createState() => _FeedItemWrapperState();
}

class _FeedItemWrapperState extends State<_FeedItemWrapper> with AutomaticKeepAliveClientMixin {
  // Mantém o estado apenas para evitar reconstruções desnecessárias ao deslizar levemente,
  // mas o VideoPlayerItem deve gerir o seu próprio dispose() quando sair da árvore.
  @override
  bool get wantKeepAlive => true; 

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
  
