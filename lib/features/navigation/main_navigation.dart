import 'package:flutter/material.dart';
import 'package:tide/core/clients/supabase_client.dart';
import 'package:tide/features/auth/presentation/screens/login_screen.dart';
import 'package:tide/features/camera/presentation/screens/camera_screen.dart';
import 'package:tide/features/chat/presentation/screens/chat_list_screen.dart';
import 'package:tide/features/feed/presentation/screens/feed_screen.dart';
import 'package:tide/features/notifications/presentation/screens/notification_screen.dart';
import 'package:tide/features/profile/presentation/screens/profile_screen.dart';
import 'package:tide/features/search/presentation/screens/search_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;
  final TideClient _tideClient = TideClient();

  void _onItemTapped(int index) async {
    if (!_tideClient.isAuthenticated && index > 1) {
      _showAuthModal();
      return;
    }

    if (index == 2) {
      print("DEBUG: Abrindo CameraScreen");
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const CameraScreen()));
      return;
    }

    if (_selectedIndex != index) {
      setState(() => _selectedIndex = index);
    }
  }

  void _showAuthModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const LoginScreen(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = _tideClient.isAuthenticated;

    final List<Widget> screens = [
      const FeedScreen(),
      const SearchScreen(),
      const SizedBox.shrink(),
      isAuthenticated ? const NotificationsScreen() : const SizedBox.shrink(),
      isAuthenticated && _tideClient.currentUserId != null ? ProfileScreen(userId: _tideClient.currentUserId!) : const SizedBox.shrink(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: _selectedIndex == 0 ? AppBar(
        backgroundColor: const Color(0xFFF8F9FA),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('Tide', style: TextStyle(color: Color(0xFF1F1F1F), fontWeight: FontWeight.bold)),
        actions: [
          // BADGE DO CHAT (Topo) - Usando método existente no TideClient
          StreamBuilder<int>(
            stream: _tideClient.getUnreadMessagesStream(),
            builder: (context, snapshot) {
              final unreadCount = snapshot.data ?? 0;
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chat_bubble_outline, color: Color(0xFF1F1F1F)),
                    onPressed: () => isAuthenticated 
                        ? Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatListScreen())) 
                        : _showAuthModal(),
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: _buildBadge(unreadCount),
                    ),
                ],
              );
            }
          ),
          const SizedBox(width: 8),
        ],
      ) : null,
      body: IndexedStack(index: _selectedIndex, children: screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF1A73E8),
        unselectedItemColor: Colors.black38,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),
          const BottomNavigationBarItem(icon: Icon(Icons.search_rounded), label: 'Search'),
          const BottomNavigationBarItem(icon: Icon(Icons.add_box_outlined), label: 'Add'),
          // BADGE DA INBOX (Fundo) - Usando método existente no TideClient
          BottomNavigationBarItem(
            icon: StreamBuilder<int>(
              stream: _tideClient.getUnreadNotificationsStream(),
              builder: (context, snapshot) {
                final unreadCount = snapshot.data ?? 0;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(_selectedIndex == 3 ? Icons.notifications : Icons.notifications_none),
                    if (unreadCount > 0)
                      Positioned(
                        right: -4,
                        top: -2,
                        child: _buildBadge(unreadCount),
                      ),
                  ],
                );
              }
            ),
            label: 'Inbox'
          ),
          const BottomNavigationBarItem(icon: Icon(Icons.person_outline_rounded), label: 'Profile'),
        ],
      ),
    );
  }

  // Widget auxiliar para manter as bolinhas de notificação consistentes
  Widget _buildBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF1A73E8), // Azul Google
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5), // Borda para destaque
      ),
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      child: Center(
        child: Text(
          count > 9 ? '9+' : '$count',
          style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}