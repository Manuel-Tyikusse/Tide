import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tide/core/clients/supabase_client.dart';
import '../widgets/user_list_tile.dart';

enum FollowListType { followers, following }

class FollowListScreen extends StatefulWidget {
  final String userId;
  final FollowListType initialType;

  const FollowListScreen({
    super.key, 
    required this.userId, 
    this.initialType = FollowListType.followers
  });

  @override
  State<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends State<FollowListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _followers = [];
  List<Map<String, dynamic>> _following = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    print("DEBUG: Inicializando FollowListScreen para o utilizador: ${widget.userId}");
    _tabController = TabController(
      length: 2, 
      vsync: this, 
      initialIndex: widget.initialType.index
    );
    _fetchFollowData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchFollowData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      print("DEBUG: Executando queries paralelas de Follow/Following...");
      final results = await Future.wait([
        TideClient().client
            .from('followers')
            .select('profiles!follower_id(*)')
            .eq('following_id', widget.userId),
        TideClient().client
            .from('followers')
            .select('profiles!following_id(*)')
            .eq('follower_id', widget.userId),
      ]);

      if (mounted) {
        setState(() {
          _followers = (results[0] as List)
              .where((e) => e['profiles'] != null)
              .map((e) => e['profiles'] as Map<String, dynamic>)
              .toList();

          _following = (results[1] as List)
              .where((e) => e['profiles'] != null)
              .map((e) => e['profiles'] as Map<String, dynamic>)
              .toList();
          
          _isLoading = false;
        });
        print("DEBUG: Dados de rede carregados. Seguidores: ${_followers.length}, A seguir: ${_following.length}");
      }
    } catch (e) {
      print("DEBUG ERROR: _fetchFollowData: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível carregar a lista.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
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
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Color(0xFF1F1F1F)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "REDE", 
          style: GoogleFonts.inter(
            fontSize: 14, 
            fontWeight: FontWeight.w900, 
            letterSpacing: 1.2,
            color: const Color(0xFF1F1F1F)
          )
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF1A73E8),
          indicatorWeight: 3,
          indicatorSize: TabBarIndicatorSize.tab,
          labelColor: const Color(0xFF1A73E8),
          unselectedLabelColor: Colors.black38,
          labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.5),
          tabs: [
            Tab(text: "${_followers.length} SEGUIDORES"),
            Tab(text: "A SEGUIR ${_following.length}"),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1A73E8), strokeWidth: 3))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildUserList(_followers),
                _buildUserList(_following),
              ],
            ),
    );
  }

  Widget _buildUserList(List<Map<String, dynamic>> users) {
    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F3F4),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.people_outline_rounded, color: Colors.black12, size: 40),
            ),
            const SizedBox(height: 16),
            Text(
              "Lista vazia", 
              style: GoogleFonts.inter(
                color: Colors.black26, 
                fontSize: 14, 
                fontWeight: FontWeight.w700
              )
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchFollowData,
      color: const Color(0xFF1A73E8),
      child: ListView.separated(
        itemCount: users.length,
        padding: const EdgeInsets.symmetric(vertical: 12),
        separatorBuilder: (context, index) => Divider(
          color: Colors.black.withOpacity(0.03), 
          indent: 72, 
          endIndent: 16
        ),
        itemBuilder: (context, index) {
          return UserListTile(user: users[index]);
        },
      ),
    );
  }
}