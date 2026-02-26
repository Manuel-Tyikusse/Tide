import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:ui';
import 'package:tide/core/clients/supabase_client.dart';
import '../../../posts/presentation/widgets/comments_modal.dart'; 

class ImagePostItem extends StatefulWidget {
  final Map<String, dynamic> post;
  const ImagePostItem({super.key, required this.post});

  @override
  State<ImagePostItem> createState() => _ImagePostItemState();
}

class _ImagePostItemState extends State<ImagePostItem> {
  final _client = TideClient();
  late bool _isLiked;
  bool _isFollowing = false;
  bool _showHeartAnim = false;
  int _currentCarouselIndex = 0;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.post['is_liked_by_user'] ?? false;
    _checkFollowStatus();
  }

  Future<void> _checkFollowStatus() async {
    final currentUserId = _client.currentUserId;
    final targetUserId = widget.post['user_id'];
    if (currentUserId == null || currentUserId == targetUserId) return;

    try {
      final response = await _client.client
          .from('followers')
          .select()
          .eq('follower_id', currentUserId)
          .eq('following_id', targetUserId)
          .maybeSingle();

      if (mounted) setState(() => _isFollowing = response != null);
    } catch (e) {
      print("DEBUG ERROR: _checkFollowStatus: $e");
    }
  }

  void _handleDoubleTap() {
    if (!_isLiked) _toggleLike();
    setState(() => _showHeartAnim = true);
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _showHeartAnim = false);
    });
  }

  void _toggleLike() async {
    final userId = _client.currentUserId;
    if (userId == null) return;
    final newState = !_isLiked;
    setState(() => _isLiked = newState);
    
    try {
      newState 
          ? await _client.likePost(widget.post['id']) 
          : await _client.unlikePost(widget.post['id']);
    } catch (e) {
      if (mounted) setState(() => _isLiked = !newState);
    }
  }

  void _toggleFollow() async {
    final userId = _client.currentUserId;
    final targetId = widget.post['user_id'];
    if (userId == null || userId == targetId) return;
    
    final originalState = _isFollowing;
    setState(() => _isFollowing = !_isFollowing);
    
    try {
      originalState 
          ? await _client.unfollowUser(targetId) 
          : await _client.followUser(targetId);
    } catch (e) {
      if (mounted) setState(() => _isFollowing = originalState);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Extração robusta do perfil
    final dynamic rawProfile = widget.post['profiles'];
    final Map<String, dynamic>? profile = (rawProfile is List && rawProfile.isNotEmpty)
        ? Map<String, dynamic>.from(rawProfile.first)
        : (rawProfile is Map ? Map<String, dynamic>.from(rawProfile) : null);

    final username = profile?['username'] ?? 'user';
    final avatarUrl = profile?['avatar_url'] ?? '';
    final bool isMyOwnPost = _client.currentUserId == widget.post['user_id'];
    final bool isAuthentic = widget.post['is_authentic'] ?? false;
    
    // --- CORREÇÃO DA GALERIA ---
    // Tenta obter media_urls (lista), se não existir tenta media_url (singular)
    final dynamic rawUrls = widget.post['media_gallery'];
    List<String> gallery = [];
    
    if (rawUrls is List) {
      gallery = List<String>.from(rawUrls);
    } else if (widget.post['media_url'] != null) {
      gallery = [widget.post['media_url'].toString()];
    }

    return GestureDetector(
      onDoubleTap: _handleDoubleTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: Colors.black),

          if (gallery.isNotEmpty)
            PageView.builder(
              itemCount: gallery.length,
              onPageChanged: (index) => setState(() => _currentCarouselIndex = index),
              itemBuilder: (context, index) => Image.network(
                gallery[index],
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF1A73E8), strokeWidth: 2));
                },
                errorBuilder: (context, error, stack) => const Center(child: Icon(Icons.broken_image, color: Colors.white24, size: 40)),
              ),
            ),

          if (isAuthentic) _buildAuthenticBadge(),

          if (gallery.length > 1) _buildCarouselIndicator(gallery.length),

          if (_showHeartAnim) _buildHeartOverlay(),

          _buildBottomOverlay(username),

          Positioned(
            right: 12,
            bottom: 60,
            child: Column(
              children: [
                _buildProfileIcon(isMyOwnPost, avatarUrl),
                const SizedBox(height: 28),
                _buildActionButton(
                  _isLiked ? Icons.favorite_rounded : Icons.favorite_outline_rounded, 
                  _isLiked ? Colors.redAccent : Colors.white, 
                  _toggleLike
                ),
                const SizedBox(height: 24),
                _buildActionButton(Icons.chat_bubble_outline_rounded, Colors.white, () {
                  showModalBottomSheet(
                    context: context, 
                    isScrollControlled: true, 
                    backgroundColor: Colors.transparent, 
                    builder: (context) => CommentsModal(postId: widget.post['id'])
                  );
                }),
                const SizedBox(height: 24),
                _buildActionButton(Icons.share_outlined, Colors.white, () {
                  Share.share('Vê este post de @$username no Tide!');
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthenticBadge() {
    return Positioned(
      top: 56,
      left: 16,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.verified_rounded, color: Color(0xFF1A73E8), size: 14),
                const SizedBox(width: 6),
                Text(
                  "AUTÊNTICO", 
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2)
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCarouselIndicator(int count) {
    return Positioned(
      top: 62,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12)
        ),
        child: Row(
          children: List.generate(count, (index) => AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: _currentCarouselIndex == index ? 12 : 6,
            height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: _currentCarouselIndex == index ? Colors.white : Colors.white38
            ),
          )),
        ),
      ),
    );
  }

  Widget _buildHeartOverlay() {
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutBack,
        builder: (context, value, child) => Transform.scale(
          scale: value * 1.8, 
          child: Icon(Icons.favorite_rounded, color: Colors.white.withOpacity(0.9), size: 100)
        ),
      ),
    );
  }

  Widget _buildBottomOverlay(String username) {
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 80, 80, 32),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("@$username", style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
              const SizedBox(height: 8),
              Text(
                widget.post['caption'] ?? '', 
                style: GoogleFonts.inter(color: Colors.white.withOpacity(0.9), fontSize: 14),
                maxLines: 3, 
                overflow: TextOverflow.ellipsis
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileIcon(bool isMyOwnPost, String avatarUrl) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)),
          child: CircleAvatar(
            radius: 24, 
            backgroundColor: const Color(0xFFF1F3F4),
            backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
            child: avatarUrl.isEmpty ? const Icon(Icons.person, color: Colors.black26, size: 24) : null,
          ),
        ),
        if (!_isFollowing && !isMyOwnPost)
          Positioned(bottom: -6, left: 0, right: 0, child: Center(
            child: GestureDetector(
              onTap: _toggleFollow, 
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(color: Color(0xFF1A73E8), shape: BoxShape.circle),
                child: const Icon(Icons.add, color: Colors.white, size: 18)
              )
            )
          )),
      ],
    );
  }

  Widget _buildActionButton(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap, 
      child: Icon(icon, color: color, size: 32, shadows: const [Shadow(blurRadius: 8, color: Colors.black45)])
    );
  }
}
