import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tide/core/clients/supabase_client.dart';
import '../../../feed/presentation/widgets/video_player_item.dart';
import '../../../profile/presentation/screens/profile_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _userResults = [];
  List<Map<String, dynamic>> _videoResults = [];
  List<String> _recentSearches = [];
  
  bool _isLoading = false;
  bool _hasSearched = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // --- LÓGICA DE PERSISTÊNCIA ATUALIZADA ---

  Future<void> _loadRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _recentSearches = prefs.getStringList('recent_searches') ?? [];
        });
      }
    } catch (e) {
      print("DEBUG ERROR: _loadRecentSearches: $e");
    }
  }

  Future<void> _saveSearch(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return;
    
    final prefs = await SharedPreferences.getInstance();
    _recentSearches.remove(cleanQuery);
    _recentSearches.insert(0, cleanQuery);
    
    if (_recentSearches.length > 8) _recentSearches.removeLast();
    await prefs.setStringList('recent_searches', _recentSearches);
    if (mounted) setState(() {});
  }

  // NOVO: Apagar uma única pesquisa
  Future<void> _deleteSingleSearch(String query) async {
    HapticFeedback.lightImpact();
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _recentSearches.remove(query);
    });
    await prefs.setStringList('recent_searches', _recentSearches);
    print("DEBUG: Pesquisa '$query' removida.");
  }

  // NOVO: Limpar todo o histórico
  Future<void> _clearAllSearches() async {
    HapticFeedback.mediumImpact();
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _recentSearches.clear();
    });
    await prefs.remove('recent_searches');
    print("DEBUG: Histórico de buscas limpo.");
  }

  // --- FIM DA LÓGICA ---

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () => _performSearch(query));
  }

  Future<void> _performSearch(String query) async {
    final cleanQuery = query.trim();
    if (mounted) {
      setState(() { 
        _isLoading = true; 
        _hasSearched = true; 
        _userResults = []; 
        _videoResults = []; 
      });
    }

    if (cleanQuery.isEmpty) {
      if (mounted) setState(() { _isLoading = false; _hasSearched = false; });
      return;
    }

    try {
      final response = await TideClient().client.rpc(
        'search_all',
        params: {'search_term': cleanQuery},
      );

      if (mounted) {
        final List<Map<String, dynamic>> users = List<Map<String, dynamic>>.from(response['users']);
        final List<Map<String, dynamic>> posts = List<Map<String, dynamic>>.from(response['posts']);

        setState(() {
          _userResults = users;
          _videoResults = posts;
        });

        if (users.isNotEmpty || posts.isNotEmpty) {
          _saveSearch(cleanQuery);
        }
      }
    } catch (e) {
      print("DEBUG ERROR: _performSearch: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 16,
        title: _buildSearchField(),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(color: Colors.black.withOpacity(0.05), height: 1),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildSearchField() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3F4),
        borderRadius: BorderRadius.circular(22),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        style: const TextStyle(color: Color(0xFF1F1F1F), fontSize: 15, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: "Procurar criadores ou vídeos",
          hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
          prefixIcon: const Icon(Icons.search_rounded, color: Colors.black45, size: 20),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.black45, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    _performSearch("");
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Color(0xFF1A73E8), strokeWidth: 3));
    if (!_hasSearched) return _buildRecentOrExplore();
    if (_userResults.isEmpty && _videoResults.isEmpty) return _buildEmptyState();

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        if (_userResults.isNotEmpty) ...[
          _buildSliverTitle("CRIADORES"),
          _buildCreatorsList(),
        ],
        if (_videoResults.isNotEmpty) ...[
          _buildSliverTitle("VÍDEOS"),
          _buildVideosGrid(),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }

  // --- UI DE BUSCAS RECENTES ATUALIZADA COM DELETE ---

  Widget _buildRecentOrExplore() {
    if (_recentSearches.isEmpty) {
      return _buildMessage(
        icon: Icons.explore_outlined,
        title: "Explorar",
        subtitle: "Pesquisa por nomes ou palavras-chave.",
      );
    }

    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 8, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "RECENTES", 
                style: GoogleFonts.inter(color: const Color(0xFF1A73E8), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.8)
              ),
              TextButton(
                onPressed: _clearAllSearches,
                child: const Text("Limpar tudo", style: TextStyle(color: Colors.black38, fontSize: 11, fontWeight: FontWeight.w600)),
              )
            ],
          ),
        ),
        ..._recentSearches.map((s) => ListTile(
          leading: const Icon(Icons.history_rounded, color: Colors.black26, size: 20),
          title: Text(s, style: const TextStyle(color: Colors.black87, fontSize: 15, fontWeight: FontWeight.w500)),
          trailing: IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.black26, size: 16),
            onPressed: () => _deleteSingleSearch(s), // DELETAR AQUI
          ),
          onTap: () {
            _searchController.text = s;
            _performSearch(s);
          },
        )),
      ],
    );
  }

  // --- RESTANTE DOS WIDGETS (CREATORS/VIDEOS) ---

  Widget _buildCreatorsList() {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 120,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: _userResults.length,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemBuilder: (context, index) {
            final user = _userResults[index];
            return GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: user['id']))),
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 34,
                      backgroundColor: const Color(0xFFF1F3F4),
                      backgroundImage: user['avatar_url'] != null ? NetworkImage(user['avatar_url']) : null,
                      child: user['avatar_url'] == null ? const Icon(Icons.person_rounded, color: Colors.black12) : null,
                    ),
                    const SizedBox(height: 8),
                    Text("@${user['username']}", style: GoogleFonts.inter(color: Colors.black87, fontSize: 11, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildVideosGrid() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 9 / 16,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final video = _videoResults[index];
            return GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(body: VideoPlayerItem(post: video)))),
              child: Image.network(video['thumbnail_url'] ?? video['media_url'] ?? '', fit: BoxFit.cover),
            );
          },
          childCount: _videoResults.length,
        ),
      ),
    );
  }

  Widget _buildSliverTitle(String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
        child: Text(title, style: GoogleFonts.inter(color: const Color(0xFF1A73E8), fontSize: 12, fontWeight: FontWeight.w900)),
      ),
    );
  }

  Widget _buildEmptyState() => _buildMessage(icon: Icons.search_off_rounded, title: "Sem resultados", subtitle: "Tenta outra palavra.");

  Widget _buildMessage({required IconData icon, required String title, required String subtitle}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 56, color: Colors.black12),
          const SizedBox(height: 16),
          Text(title, style: GoogleFonts.inter(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.w800)),
          Text(subtitle, style: const TextStyle(color: Colors.black38, fontSize: 14)),
        ],
      ),
    );
  }
}