import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tide/core/clients/supabase_client.dart';

class AddParticipantsScreen extends StatefulWidget {
  final String roomId;
  final List<String> existingParticipantIds;

  const AddParticipantsScreen({
    super.key, 
    required this.roomId, 
    required this.existingParticipantIds
  });

  @override
  State<AddParticipantsScreen> createState() => _AddParticipantsScreenState();
}

class _AddParticipantsScreenState extends State<AddParticipantsScreen> {
  final _client = TideClient();
  List<Map<String, dynamic>> _contacts = [];
  final Set<String> _selectedIds = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    final userId = _client.currentUserId;
    if (userId == null) return;
    
    print("DEBUG: Carregando contactos para adicionar ao grupo ${widget.roomId}");
    
    try {
      // Busca utilizadores que o utilizador atual segue
      final following = await _client.getFollowing(userId);
      
      setState(() {
        _contacts = following.where((u) {
          final profile = u['profiles'] as Map<String, dynamic>?;
          // Filtra para não mostrar quem já é membro do grupo
          return profile != null && !widget.existingParticipantIds.contains(profile['id']);
        }).map((u) => u['profiles'] as Map<String, dynamic>).toList();
      });
      print("DEBUG: ${_contacts.length} contactos disponíveis encontrados.");
    } catch (e) {
      print("DEBUG ERROR: _loadContacts: $e");
    }
  }

  Future<void> _addMembers() async {
    if (_selectedIds.isEmpty) return;
    setState(() => _isLoading = true);

    try {
      print("DEBUG: Adicionando ${_selectedIds.length} novos membros ao grupo ${widget.roomId}");
      
      final List<Map<String, dynamic>> newParticipants = _selectedIds.map((id) => {
        'room_id': int.parse(widget.roomId),
        'user_id': id,
        'role': 'member'
      }).toList();

      // Inserção em massa na tabela de participantes
      await _client.client.from('chat_participants').insert(newParticipants);
      
      if (mounted) {
        print("DEBUG: Membros adicionados com sucesso.");
        Navigator.pop(context, true);
      }
    } catch (e) {
      print("DEBUG ERROR: _addMembers: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao adicionar membros.'),
            backgroundColor: Colors.redAccent,
          )
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Fundo Claro Google
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFF1F1F1F)),
        title: Text(
          'ADICIONAR AO GRUPO', 
          style: GoogleFonts.inter(
            fontSize: 12, 
            fontWeight: FontWeight.w900, 
            letterSpacing: 1.2,
            color: const Color(0xFF1F1F1F)
          )
        ),
        actions: [
          if (_selectedIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: TextButton(
                onPressed: _isLoading ? null : _addMembers,
                child: _isLoading 
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1A73E8)))
                  : Text(
                      'ADICIONAR (${_selectedIds.length})', 
                      style: const TextStyle(
                        color: Color(0xFF1A73E8), // Azul Google
                        fontWeight: FontWeight.bold,
                        fontSize: 13
                      )
                    ),
              ),
            )
        ],
      ),
      body: _contacts.isEmpty 
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.person_add_disabled_outlined, size: 40, color: Colors.black12),
                const SizedBox(height: 16),
                Text(
                  'Nenhum contacto novo disponível.', 
                  style: GoogleFonts.inter(color: Colors.black26, fontSize: 14)
                ),
              ],
            ))
        : ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: _contacts.length,
            separatorBuilder: (context, index) => const Divider(color: Colors.black12, height: 1, indent: 72),
            itemBuilder: (context, index) {
              final user = _contacts[index];
              final String userId = user['id'];
              final isSelected = _selectedIds.contains(userId);
              
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                leading: CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFFF1F3F4), // Cinza-azulado suave
                  backgroundImage: user['avatar_url'] != null 
                      ? NetworkImage(user['avatar_url']) 
                      : null,
                  child: user['avatar_url'] == null 
                      ? const Icon(Icons.person, color: Colors.black26) 
                      : null,
                ),
                title: Text(
                  user['username'] ?? 'User', 
                  style: GoogleFonts.inter(
                    color: const Color(0xFF1F1F1F), 
                    fontWeight: FontWeight.w600,
                    fontSize: 15
                  )
                ),
                trailing: Icon(
                  isSelected ? Icons.check_circle : Icons.add_circle_outline, 
                  color: isSelected ? const Color(0xFF1A73E8) : Colors.black12,
                  size: 28,
                ),
                onTap: () {
                  setState(() {
                    isSelected ? _selectedIds.remove(userId) : _selectedIds.add(userId);
                  });
                },
              );
            },
          ),
    );
  }
}