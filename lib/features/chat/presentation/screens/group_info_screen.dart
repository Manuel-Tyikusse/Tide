import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tide/core/clients/supabase_client.dart';
import 'package:tide/features/chat/presentation/screens/add_participants_screen.dart';
import 'package:tide/features/profile/presentation/widgets/user_list_tile.dart';

class GroupInfoScreen extends StatefulWidget {
  final String roomId;

  const GroupInfoScreen({super.key, required this.roomId});

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  final _client = TideClient();
  late Future<Map<String, dynamic>> _groupDetailsFuture;
  final _groupNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadGroupDetails();
  }

  void _loadGroupDetails() {
    if (mounted) {
      print("DEBUG: Carregando detalhes do grupo ${widget.roomId}");
      setState(() {
        _groupDetailsFuture = _client.client
            .from('chat_rooms')
            .select('*, chat_participants(*, profiles(*))')
            .eq('id', widget.roomId)
            .single();
      });
    }
  }

  Future<void> _updateGroupName() async {
    final newName = _groupNameController.text.trim();
    if (newName.isEmpty) return;

    try {
      print("DEBUG: Atualizando nome do grupo para: $newName");
      await _client.client
          .from('chat_rooms')
          .update({'group_name': newName})
          .eq('id', widget.roomId);

      if (mounted) {
        _showSnackBar('Nome do grupo atualizado!');
        _loadGroupDetails();
        FocusScope.of(context).unfocus();
      }
    } catch (e) {
      print("DEBUG ERROR: _updateGroupName: $e");
      _showSnackBar('Erro ao atualizar o nome.', isError: true);
    }
  }

  Future<void> _removeParticipant(String userId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Remover Participante', 
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: const Color(0xFF1F1F1F))),
        content: Text('Remover este utilizador do grupo?', 
          style: GoogleFonts.inter(color: Colors.black54)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false), 
            child: Text('Cancelar', style: TextStyle(color: Colors.black45))),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true), 
            child: const Text('Remover', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      print("DEBUG: Removendo participante $userId do grupo ${widget.roomId}");
      await _client.client
          .from('chat_participants')
          .delete()
          .match({'room_id': widget.roomId, 'user_id': userId});

      if (mounted) {
        _showSnackBar('Participante removido.');
        _loadGroupDetails();
      }
    } catch (e) {
      print("DEBUG ERROR: _removeParticipant: $e");
      _showSnackBar('Erro ao remover participante.', isError: true);
    }
  }

  Future<void> _leaveGroup() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Sair do Grupo', 
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: const Color(0xFF1F1F1F))),
        content: Text('Tem a certeza que quer sair deste grupo?', 
          style: GoogleFonts.inter(color: Colors.black54)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false), 
            child: Text('Cancelar', style: TextStyle(color: Colors.black45))),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true), 
            child: const Text('Sair', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
        ],
      ),
    );

    if (confirm != true || _client.currentUserId == null) return;

    try {
      print("DEBUG: Utilizador atual saindo do grupo ${widget.roomId}");
      await _client.client
          .from('chat_participants')
          .delete()
          .match({'room_id': widget.roomId, 'user_id': _client.currentUserId!});

      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      print("DEBUG ERROR: _leaveGroup: $e");
      _showSnackBar('Erro ao sair do grupo.', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter(fontWeight: FontWeight.w600)), 
        backgroundColor: isError ? Colors.redAccent : const Color(0xFF1A73E8),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text('DETALHES DO GRUPO', 
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: const Color(0xFF1F1F1F))),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Color(0xFF1F1F1F)),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _groupDetailsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF1A73E8)));
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(child: Text('Erro ao carregar detalhes.', style: GoogleFonts.inter(color: Colors.black26)));
          }

          final group = snapshot.data!;
          final participants = (group['chat_participants'] as List).cast<Map<String, dynamic>>();
          
          final currentUserParticipation = participants.firstWhere(
            (p) => p['user_id'] == _client.currentUserId,
            orElse: () => {'role': 'member'},
          );
          final bool isAdmin = currentUserParticipation['role'] == 'admin';

          if (_groupNameController.text.isEmpty) {
            _groupNameController.text = group['group_name'] ?? group['name'] ?? '';
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('NOME DO GRUPO', 
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.black38, letterSpacing: 1.2)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _groupNameController,
                        enabled: isAdmin,
                        style: const TextStyle(color: Color(0xFF1F1F1F), fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFFF1F3F4),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                    if (isAdmin)
                      Padding(
                        padding: const EdgeInsets.only(left:8.0),
                        child: IconButton(
                          icon: const Icon(Icons.check_circle, color: Color(0xFF1A73E8), size: 30),
                          onPressed: _updateGroupName,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 32),
                Text('PARTICIPANTES (${participants.length})', 
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.black38, letterSpacing: 1.2)),
                const SizedBox(height: 12),
                
                if (isAdmin)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.black.withOpacity(0.05))
                    ),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFF1A73E8),
                        child: Icon(Icons.person_add, color: Colors.white, size: 20),
                      ),
                      title: Text('Adicionar Membros', 
                        style: GoogleFonts.inter(color: const Color(0xFF1F1F1F), fontWeight: FontWeight.bold, fontSize: 14)),
                      trailing: const Icon(Icons.chevron_right, color: Colors.black26),
                      onTap: () async {
                        final result = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AddParticipantsScreen(
                              roomId: widget.roomId,
                              existingParticipantIds: participants.map((p) => p['user_id'].toString()).toList(),
                            ),
                          ),
                        );
                        if (result == true) _loadGroupDetails();
                      },
                    ),
                  ),

                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.black.withOpacity(0.05))
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: participants.length,
                    separatorBuilder: (context, index) => const Divider(height: 1, indent: 70, color: Color(0xFFF1F3F4)),
                    itemBuilder: (context, index) {
                      final participant = participants[index];
                      final userProfileMap = participant['profiles'] as Map<String, dynamic>?;
                      final bool isParticipantAdmin = participant['role'] == 'admin';

                      if (userProfileMap == null) return const SizedBox.shrink();

                      return UserListTile(
                        user: userProfileMap,
                        trailing: isAdmin && participant['user_id'] != _client.currentUserId
                            ? IconButton(
                                icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
                                onPressed: () => _removeParticipant(participant['user_id']),
                              )
                            : (isParticipantAdmin 
                                ? Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1A73E8).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8)
                                    ),
                                    child: const Text('Admin', 
                                      style: TextStyle(color: Color(0xFF1A73E8), fontSize: 11, fontWeight: FontWeight.bold)),
                                  )
                                : null),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: _leaveGroup,
                    icon: const Icon(Icons.exit_to_app, color: Colors.redAccent, size: 18),
                    label: Text('SAIR DO GRUPO', 
                      style: GoogleFonts.inter(color: Colors.redAccent, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1.1)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.redAccent, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }
}