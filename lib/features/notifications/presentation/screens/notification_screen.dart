import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/clients/supabase_client.dart';
// Importamos o teu NotificationTile que já criaste
import '../widgets/notification_tile.dart'; 

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final TideClient _tide = TideClient();
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  StreamSubscription? _streamSubscription;

  @override
  void initState() {
    super.initState();
    _setupNotifications();
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    super.dispose();
  }

  void _setupNotifications() {
    final userId = _tide.currentUserId;
    if (userId == null) return;

    _fetchNotifications();

    _streamSubscription = _tide.client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('receiver_id', userId)
        .listen((_) => _fetchNotifications(isRefresh: true));
  }

  Future<void> _fetchNotifications({bool isRefresh = false}) async {
    final userId = _tide.currentUserId;
    if (userId == null) return;

    if (!isRefresh && mounted) setState(() => _isLoading = true);

    try {
      // Melhoramos o SELECT para garantir que o post traz o seu autor (profiles)
      // Isso evita erros ao abrir o PostDetailScreen
      final response = await _tide.client
          .from('notifications')
          .select('''
            *,
            sender:sender_id(id, username, avatar_url),
            posts:post_id(
              *,
              profiles:user_id(id, username, avatar_url)
            )
          ''')
          .eq('receiver_id', userId)
          .order('created_at', ascending: false)
          .limit(50);

      if (mounted) {
        setState(() {
          _notifications = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });

        if (_notifications.any((n) => n['is_read'] == false)) {
          _markAsRead(userId);
        }
      }
    } catch (e) {
      print("DEBUG ERROR: _fetchNotifications: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markAsRead(String userId) async {
    try {
      await _tide.client
        .from('notifications')
        .update({'is_read': true})
        .match({'receiver_id': userId, 'is_read': false});
    } catch (e) {
      print("DEBUG ERROR: _markAsRead: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text("ATIVIDADE", 
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.5)
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1), 
          child: Container(color: Colors.black.withOpacity(0.05), height: 1)
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Color(0xFF1A73E8)));
    if (_notifications.isEmpty) return _buildEmptyState();

    return RefreshIndicator(
      onRefresh: () => _fetchNotifications(isRefresh: true),
      child: ListView.separated(
        itemCount: _notifications.length,
        separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F3F4)),
        itemBuilder: (context, index) {
          // AQUI: Usamos o teu NotificationTile clicável
          return NotificationTile(notification: _notifications[index]);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
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
            child: const Icon(Icons.notifications_none_rounded, color: Colors.black12, size: 48),
          ),
          const SizedBox(height: 24),
          Text(
            "Tudo em dia!", 
            style: GoogleFonts.inter(
              color: const Color(0xFF1F1F1F), 
              fontSize: 16, 
              fontWeight: FontWeight.w800
            )
          ),
          const SizedBox(height: 8),
          Text(
            "Não tens novas notificações.", 
            style: GoogleFonts.inter(color: Colors.black38, fontSize: 13)
          ),
        ],
      ),
    );
  }
}
