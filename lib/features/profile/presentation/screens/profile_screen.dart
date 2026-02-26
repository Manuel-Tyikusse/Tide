import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tide/features/chat/presentation/screens/chat_room_screen.dart';
import '../../../../core/clients/supabase_client.dart';
import 'edit_profile_screen.dart';
import 'settings_screen.dart';
import 'follow_list_screen.dart';
import '../../../posts/presentation/screens/post_detail_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId;

  const ProfileScreen({super.key, this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  TabController? _tabController;
  Map<String, dynamic>? _profileData;
  List<Map<String, dynamic>> _userPosts = [];
  List<Map<String, dynamic>> _likedPosts = [];
  
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = "";

  bool _isMe = false;
  bool _isFollowing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    print("DEBUG: Inicializando ProfileScreen para o utilizador: ${widget.userId ?? 'Próprio'}");
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProfile());
  }
  
  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    final tide = TideClient();
    final myId = tide.currentUserId;
    final targetId = widget.userId ?? myId;

    if (targetId == null) {
      print("DEBUG ERROR: Sessão não encontrada.");
      if (mounted) setState(() { _isLoading = false; _hasError = true; _errorMessage = "Inicie sessão para ver o perfil."; });
      return;
    }

    setState(() => _isMe = (targetId == myId));

    try {
      print("DEBUG: Carregando dados do perfil $targetId...");
      final profile = await tide.getProfile(targetId);

      final List<Future> queries = [
        tide.client
            .from('posts')
            .select('*, profiles!posts_user_id_fkey(*)')
            .eq('user_id', targetId)
            .order('created_at', ascending: false),
      ];

      if (_isMe) {
        queries.add(
          tide.client
              .from('likes')
              .select('posts(*, profiles!posts_user_id_fkey(*))')
              .eq('user_id', targetId)
              .order('created_at', ascending: false)
        );
      }

      final results = await Future.wait(queries);

      if (mounted) {
        setState(() {
          _profileData = profile;
          final rawPosts = results[0] as List<dynamic>;
          _userPosts = rawPosts.map((e) => Map<String, dynamic>.from(e)).toList();
          
          if (_isMe && results.length > 1) {
            final rawLikes = results[1] as List<dynamic>;
            _likedPosts = rawLikes
                .where((l) => l['posts'] != null)
                .map((l) => Map<String, dynamic>.from(l['posts']))
                .toList();
          } else {
            _likedPosts = [];
          }
        });
      }

      if (!_isMe && myId != null) {
        final followRes = await tide.client
            .from('followers')
            .select()
            .eq('follower_id', myId)
            .eq('following_id', targetId)
            .maybeSingle();
        if (mounted) setState(() => _isFollowing = followRes != null);
      }
      print("DEBUG: Perfil e posts carregados com sucesso.");

    } catch (e) {
      print("DEBUG ERROR: _loadProfile: $e");
      if (mounted) setState(() { _hasError = true; _errorMessage = "Ocorreu um erro ao carregar o perfil."; });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleFollow() async {
    final tide = TideClient();
    final myId = tide.currentUserId;
    final targetId = _profileData?['id'];
    if (myId == null || targetId == null || _isMe) return;

    final originalFollowState = _isFollowing;
    HapticFeedback.selectionClick();
    
    setState(() {
      _isFollowing = !originalFollowState;
      if (_profileData != null) {
        _profileData!['followers_count'] = (_profileData!['followers_count'] ?? 0) + (originalFollowState ? -1 : 1);
      }
    });

    try {
      print("DEBUG: Toggle follow para $targetId (Estado anterior: $originalFollowState)");
      if (originalFollowState) {
        await tide.unfollowUser(targetId);
      } else {
        await tide.followUser(targetId);
      }
    } catch (e) {
      print("DEBUG ERROR: _toggleFollow: $e");
      if (mounted) {
        setState(() {
          _isFollowing = originalFollowState;
          _profileData!['followers_count'] = (_profileData!['followers_count'] ?? 0) + (originalFollowState ? 1 : -1);
        });
      }
    }
  }

  void _navigateToFollowList(FollowListType type) {
    if (_profileData == null) return;
    print("DEBUG: Navegando para lista de ${type.name}");
    Navigator.push(context, MaterialPageRoute(
      builder: (context) => FollowListScreen(userId: _profileData!['id'], initialType: type),
    ));
  }

  void _navigateToPostDetail(Map<String, dynamic> post) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => PostDetailScreen(post: post)));
  }
  
  Future<void> _openChat() async {
    if (_isMe || _profileData == null) return;
    try {
      print("DEBUG: Abrindo chat privado com ${_profileData!['id']}");
      final roomId = await TideClient().createOrGetPrivateChat(_profileData!['id']);
      if (mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => ChatRoomScreen(roomId: roomId.toString())));
    } catch (e) {
      print("DEBUG ERROR: _openChat: $e");
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao abrir chat.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(backgroundColor: Colors.white, body: Center(child: CircularProgressIndicator(color: Color(0xFF1A73E8), strokeWidth: 3)));
    }

    if (_hasError || _profileData == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(backgroundColor: Colors.white, elevation: 0),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off_rounded, color: Colors.black12, size: 64),
              const SizedBox(height: 16),
              Text(_errorMessage, style: GoogleFonts.inter(color: Colors.black38, fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 24),
              TextButton.icon(
                onPressed: _loadProfile, 
                icon: const Icon(Icons.refresh_rounded, color: Color(0xFF1A73E8)),
                label: Text("TENTAR NOVAMENTE", style: GoogleFonts.inter(color: Color(0xFF1A73E8), fontWeight: FontWeight.w800, fontSize: 13))
              ),
            ],
          )
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        onRefresh: _loadProfile,
        color: const Color(0xFF1A73E8),
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverAppBar(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              pinned: true,
              elevation: 0,
              centerTitle: true,
              leading: widget.userId != null ? IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Colors.black), onPressed: () => Navigator.pop(context)) : null,
              title: Text(_profileData!['username']?.toUpperCase() ?? "PERFIL", 
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: Colors.black)),
              actions: [
                IconButton(icon: const Icon(Icons.share_rounded, size: 22, color: Colors.black), onPressed: () => Share.share('Vê o perfil de ${_profileData!['username']} no Tide!')),
                if (_isMe) IconButton(icon: const Icon(Icons.settings_outlined, size: 22, color: Colors.black), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()))),
              ],
            ),
            SliverToBoxAdapter(
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  _buildAvatar(),
                  const SizedBox(height: 12),
                  Text("@${_profileData!['username']}", style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black)),
                  if (_profileData!['bio'] != null && _profileData!['bio'].toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                      child: Text(_profileData!['bio'], textAlign: TextAlign.center, style: GoogleFonts.inter(color: Colors.black54, fontSize: 14, height: 1.5)),
                    ),
                  const SizedBox(height: 24),
                  _buildStatsRow(),
                  const SizedBox(height: 24),
                  _buildActionButtons(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverAppBarDelegate(
                TabBar(
                  controller: _tabController,
                  indicatorColor: const Color(0xFF1A73E8),
                  indicatorWeight: 3,
                  labelColor: const Color(0xFF1A73E8),
                  unselectedLabelColor: Colors.black26,
                  dividerColor: Colors.black.withOpacity(0.05),
                  tabs: const [Tab(icon: Icon(Icons.grid_view_rounded, size: 22)), Tab(icon: Icon(Icons.favorite_rounded, size: 22))],
                ),
              ),
            ),
          ],
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildPostsGrid(_userPosts),
              _buildPostsGrid(_likedPosts, isLikesTab: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    final url = _profileData?['avatar_url'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.black.withOpacity(0.05), width: 1.5)),
      child: CircleAvatar(
        radius: 48,
        backgroundColor: const Color(0xFFF1F3F4),
        backgroundImage: url != null && url.toString().isNotEmpty ? NetworkImage(url) : null,
        child: url == null || url.toString().isEmpty ? const Icon(Icons.person, size: 40, color: Colors.black12) : null,
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _statItem("Publicações", _profileData?['posts_count'] ?? 0),
        GestureDetector(onTap: () => _navigateToFollowList(FollowListType.followers), child: _statItem("Seguidores", _profileData?['followers_count'] ?? 0)),
        GestureDetector(onTap: () => _navigateToFollowList(FollowListType.following), child: _statItem("A seguir", _profileData?['following_count'] ?? 0)),
      ],
    );
  }

  Widget _buildActionButtons() {
    if (_isMe) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen())).then((_) => _loadProfile()),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.black.withOpacity(0.1)), 
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 14)
            ),
            child: Text("EDITAR PERFIL", style: GoogleFonts.inter(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: _toggleFollow,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isFollowing ? const Color(0xFFF1F3F4) : const Color(0xFF1A73E8),
                foregroundColor: _isFollowing ? Colors.black87 : Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(_isFollowing ? "A SEGUIR" : "SEGUIR", style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton(
              onPressed: _openChat,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.black.withOpacity(0.1)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14)
              ),
              child: Text("MENSAGEM", style: GoogleFonts.inter(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostsGrid(List<Map<String, dynamic>> posts, {bool isLikesTab = false}) {
    if (posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isLikesTab ? Icons.favorite_outline_rounded : Icons.grid_view_rounded, 
              color: Colors.black12, 
              size: 48
            ),
            const SizedBox(height: 16),
            Text(
              isLikesTab && !_isMe ? "Esta lista é privada." : "Ainda sem publicações.", 
              style: GoogleFonts.inter(color: Colors.black26, fontSize: 14, fontWeight: FontWeight.w600)
            ),
          ],
        )
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.only(top: 2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 2, crossAxisSpacing: 2),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        final mediaUrl = post['media_url'] as String?;
        return GestureDetector(
          onTap: () => _navigateToPostDetail(post),
          child: Container(
            color: const Color(0xFFF8F9FA),
            child: mediaUrl != null 
              ? Image.network(mediaUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.black12))
              : const Icon(Icons.image_not_supported, color: Colors.black12),
          ),
        );
      },
    );
  }

  Widget _statItem(String label, int count) {
    return Column(
      children: [
        Text(count.toString(), style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.black)),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: Colors.black38, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);
  final TabBar _tabBar;
  @override double get minExtent => _tabBar.preferredSize.height;
  @override double get maxExtent => _tabBar.preferredSize.height;
  @override Widget build(context, shrinkOffset, overlapsContent) => Container(color: Colors.white, child: _tabBar);
  @override bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => true;
}
