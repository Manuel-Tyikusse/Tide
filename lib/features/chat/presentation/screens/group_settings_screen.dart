import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tide/core/clients/supabase_client.dart';

class GroupSettingsScreen extends StatefulWidget {
  final Map<String, dynamic> roomData;
  const GroupSettingsScreen({super.key, required this.roomData});

  @override
  State<GroupSettingsScreen> createState() => _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends State<GroupSettingsScreen> {
  final _client = TideClient();
  final _nameController = TextEditingController();
  File? _imageFile;
  bool _isLoading = false;
  List<dynamic> _members = [];

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.roomData['group_name'] ?? "";
    _members = widget.roomData['chat_participants'] ?? [];
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 60);
    if (picked != null) {
      print("DEBUG: Imagem de grupo selecionada: ${picked.path}");
      setState(() => _imageFile = File(picked.path));
    }
  }

  Future<void> _saveChanges() async {
    setState(() => _isLoading = true);
    print("DEBUG: Iniciando atualização do perfil do grupo ${widget.roomData['id']}");
    try {
      await _client.updateGroupProfile(
        roomId: widget.roomData['id'],
        name: _nameController.text.trim(),
        avatarFile: _imageFile,
      );
      if (mounted) {
        print("DEBUG: Alterações de grupo salvas com sucesso.");
        Navigator.pop(context, true);
      }
    } catch (e) {
      print("DEBUG ERROR: _saveChanges: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Erro ao salvar perfil"), backgroundColor: Colors.redAccent)
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _removeMember(String userId, String username) async {
    try {
      print("DEBUG: Removendo membro $username ($userId) do grupo");
      await _client.removeMemberFromGroup(widget.roomData['id'], userId);
      setState(() {
        _members.removeWhere((m) => m['user_id'] == userId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("$username removido"), backgroundColor: const Color(0xFF1A73E8))
      );
    } catch (e) {
      print("DEBUG ERROR: _removeMember: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Erro ao remover"), backgroundColor: Colors.redAccent)
      );
    }
  }

  Future<void> _leaveGroup() async {
    final bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text("SAIR DO GRUPO", 
          style: GoogleFonts.inter(color: const Color(0xFF1F1F1F), fontWeight: FontWeight.w900, fontSize: 14)),
        content: const Text("Tens a certeza que desejas sair deste grupo?", 
          style: TextStyle(color: Colors.black54)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false), 
            child: const Text("CANCELAR", style: TextStyle(color: Colors.black45))
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text("SAIR", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))
          ),
        ],
      )
    ) ?? false;

    if (confirm) {
      setState(() => _isLoading = true);
      print("DEBUG: Utilizador a abandonar grupo ${widget.roomData['id']}");
      try {
        await _client.leaveGroup(widget.roomData['id']);
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst); 
        }
      } catch (e) {
        print("DEBUG ERROR: _leaveGroup: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Erro ao sair do grupo"), backgroundColor: Colors.redAccent)
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFF1F1F1F)),
        title: Text("EDITAR GRUPO", 
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: const Color(0xFF1F1F1F))),
        actions: [
          if (_isLoading) 
            const Center(child: Padding(padding: EdgeInsets.all(16.0), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1A73E8)))))
          else
            TextButton(
              onPressed: _saveChanges,
              child: const Text("SALVAR", style: TextStyle(color: Color(0xFF1A73E8), fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 30),
            _buildAvatarSection(),
            const SizedBox(height: 24),
            _buildNameField(),
            const SizedBox(height: 32),
            _buildMembersList(),
            const SizedBox(height: 40),
            _buildLeaveButton(),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarSection() {
    return GestureDetector(
      onTap: _pickImage,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black12, width: 1),
            ),
            child: CircleAvatar(
              radius: 55,
              backgroundColor: const Color(0xFFF1F3F4),
              backgroundImage: _imageFile != null 
                  ? FileImage(_imageFile!) 
                  : (widget.roomData['group_avatar_url'] != null ? NetworkImage(widget.roomData['group_avatar_url']) : null) as ImageProvider?,
              child: _imageFile == null && widget.roomData['group_avatar_url'] == null
                  ? const Icon(Icons.groups_rounded, color: Colors.black26, size: 40)
                  : null,
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(color: Color(0xFF1A73E8), shape: BoxShape.circle),
            child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildNameField() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("NOME DO GRUPO", 
            style: GoogleFonts.inter(color: Colors.black38, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
          const SizedBox(height: 10),
          TextField(
            controller: _nameController,
            style: const TextStyle(color: Color(0xFF1F1F1F), fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF1F3F4),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              hintText: "Insere o nome do grupo",
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMembersList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Text("MEMBROS (${_members.length})", 
            style: GoogleFonts.inter(color: Colors.black38, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.black.withOpacity(0.05)),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _members.length,
            separatorBuilder: (context, index) => const Divider(height: 1, indent: 70, color: Color(0xFFF1F3F4)),
            itemBuilder: (context, index) {
              final member = _members[index];
              final profile = member['profiles'];
              final isMe = profile['id'] == _client.currentUserId;
              final bool isAdmin = member['role'] == 'admin';

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFFF1F3F4),
                  backgroundImage: profile['avatar_url'] != null ? NetworkImage(profile['avatar_url']) : null,
                  child: profile['avatar_url'] == null ? const Icon(Icons.person, color: Colors.black26) : null,
                ),
                title: Text(profile['username'] ?? "User", 
                  style: GoogleFonts.inter(color: const Color(0xFF1F1F1F), fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: Text(isAdmin ? "Administrador" : "Membro", 
                  style: TextStyle(color: isAdmin ? const Color(0xFF1A73E8) : Colors.black26, fontSize: 11, fontWeight: isAdmin ? FontWeight.bold : FontWeight.normal)),
                trailing: (!isMe && !isAdmin) 
                    ? IconButton(
                        icon: const Icon(Icons.person_remove_outlined, color: Colors.redAccent, size: 20),
                        onPressed: () => _removeMember(profile['id'], profile['username']),
                      )
                    : (isMe ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: const Color(0xFFF1F3F4), borderRadius: BorderRadius.circular(8)),
                        child: const Text("Tu", style: TextStyle(color: Colors.black45, fontSize: 10, fontWeight: FontWeight.bold)),
                      ) : null),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLeaveButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: OutlinedButton.icon(
          onPressed: _isLoading ? null : _leaveGroup,
          icon: const Icon(Icons.exit_to_app_rounded, color: Colors.redAccent, size: 18),
          label: Text("SAIR DO GRUPO", 
            style: GoogleFonts.inter(color: Colors.redAccent, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1.1)),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.redAccent, width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }
}