import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tide/core/clients/supabase_client.dart';
import 'package:tide/features/chat/presentation/screens/chat_room_screen.dart';
import 'package:tide/features/chat/presentation/widgets/chat_list_tile.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final _client = TideClient();
  
  // Variável para manter o stream ativo e evitar recriações desnecessárias
  late Stream<List<Map<String, dynamic>>> _chatRoomsStream;

  @override
  void initState() {
    super.initState();
    print("DEBUG: Inicializando ChatListScreen com Realtime");
    _setupChatStream();
  }

  void _setupChatStream() {
    // O TideClient deve gerir a lógica de unir os dados da sala com 
    // a última mensagem. O stream garante que se houver mudança, a UI reflete.
    _chatRoomsStream = _client.getChatRoomsStream();
  }

  Future<void> _createNewGroup(String name) async {
    try {
      print("DEBUG: Criando novo grupo: $name");
      await _client.createGroup(name);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Grupo "$name" criado!'),
            backgroundColor: const Color(0xFF1A73E8),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print("DEBUG ERROR: _createNewGroup: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          "CONVERSAS",
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w900, 
            fontSize: 13, 
            letterSpacing: 2, 
            color: const Color(0xFF1F1F1F)
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF1F1F1F), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _chatRoomsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF1A73E8)),
            );
          }

          if (snapshot.hasError) {
            print("DEBUG ERROR: Stream ChatList: ${snapshot.error}");
            return Center(
              child: Text(
                'Erro ao sincronizar conversas',
                style: GoogleFonts.inter(color: Colors.black26),
              ),
            );
          }

          final chatRooms = snapshot.data ?? [];
          if (chatRooms.isEmpty) return _buildEmptyState();

          return RefreshIndicator(
            onRefresh: () async => setState(() => _setupChatStream()),
            color: const Color(0xFF1A73E8),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: chatRooms.length,
              separatorBuilder: (context, index) => const Divider(
                color: Colors.black12, 
                height: 1, 
                indent: 80
              ),
              itemBuilder: (context, index) {
                final room = chatRooms[index];
                final int roomId = room['id'];
                final bool isGroup = room['is_group'] ?? false;
                
                // Lógica de definição de nome do Chat
                String chatName = "";
                if (isGroup) {
                  chatName = room['group_name'] ?? "Grupo sem nome";
                } else {
                  final participants = room['chat_participants'] as List?;
                  final other = participants?.firstWhere(
                    (p) => p['user_id'] != _client.currentUserId,
                    orElse: () => null,
                  );
                  chatName = other?['profiles']?['username'] ?? "Utilizador";
                }

                return ChatListTile(
                  chatRoom: room,
                  onTap: () async {
                    print("DEBUG: Abrindo chat $roomId e marcando como lido");
                    // Marca como lido imediatamente para feedback visual rápido
                    await _client.markMessagesAsRead(roomId);
                    
                    if (context.mounted) {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatRoomScreen(
                            roomId: roomId.toString(), 
                            chatName: chatName
                          ),
                        ),
                      );
                      // Ao voltar do chat, garantimos que a lista reflete o estado lido
                      print("DEBUG: Voltando à lista, atualizando estados");
                    }
                  },
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF1A73E8),
        elevation: 2,
        onPressed: () => _showCreateGroupDialog(),
        child: const Icon(Icons.group_add_rounded, color: Colors.white),
      ),
    );
  }

  void _showCreateGroupDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          "NOVO GRUPO", 
          style: GoogleFonts.inter(
            color: const Color(0xFF1F1F1F), 
            fontWeight: FontWeight.w900, 
            fontSize: 14,
            letterSpacing: 1
          )
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Color(0xFF1F1F1F)),
          decoration: InputDecoration(
            hintText: "Nome do grupo...", 
            hintStyle: const TextStyle(color: Colors.black26),
            filled: true,
            fillColor: const Color(0xFFF1F3F4),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text("CANCELAR", style: TextStyle(color: Colors.black45)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A73E8),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                _createNewGroup(controller.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text("CRIAR", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.chat_bubble_outline_rounded, size: 48, color: Colors.black12),
          const SizedBox(height: 16),
          Text(
            'Nenhuma conversa ainda', 
            style: GoogleFonts.inter(color: Colors.black26, fontSize: 14)
          ),
        ],
      ),
    );
  }
}