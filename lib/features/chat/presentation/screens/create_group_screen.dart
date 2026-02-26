import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/clients/supabase_client.dart';
import 'chat_room_screen.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _client = TideClient();
  
  File? _groupAvatar;
  bool _isLoading = false;
  
  List<Map<String, dynamic>> _followingList = [];
  final Set<String> _selectedMemberIds = {};

  @override
  void initState() {
    super.initState();
    _fetchFollowing();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _fetchFollowing() async {
    try {
      final userId = _client.currentUserId;
      if (userId == null) return;
      
      print("DEBUG: Carregando lista de seguidores para criação de grupo.");
      final following = await _client.getFollowing(userId);
      if (mounted) {
        setState(() => _followingList = following);
      }
    } catch (e) {
      print("DEBUG ERROR: _fetchFollowing: $e");
      _showSnackBar('Erro ao buscar contactos.', isError: true);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (pickedFile != null) {
      setState(() => _groupAvatar = File(pickedFile.path));
    }
  }

  void _toggleMemberSelection(String userId) {
    setState(() {
      if (_selectedMemberIds.contains(userId)) {
        _selectedMemberIds.remove(userId);
      } else {
        _selectedMemberIds.add(userId);
      }
    });
  }

  Future<void> _createGroup() async {
    if (!_formKey.currentState!.validate()) return;
    if (_groupAvatar == null) {
      _showSnackBar('Adiciona uma imagem ao grupo.', isError: true);
      return;
    }
    if (_selectedMemberIds.isEmpty) {
      _showSnackBar('Seleciona pelo menos um membro.', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      print("DEBUG: Criando grupo '${_nameController.text}' com ${_selectedMemberIds.length} membros.");
      final newRoom = await _client.createGroupChat(
        _nameController.text.trim(),
        _groupAvatar!,
        _selectedMemberIds.toList(),
      );

      if (mounted) {
        final String roomId = newRoom['id'].toString();
        print("DEBUG: Grupo criado com sucesso. ID: $roomId");

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => ChatRoomScreen(roomId: roomId, chatName: _nameController.text.trim()),
          ),
          (route) => route.isFirst,
        );
      }
    } catch (e) {
      print("DEBUG ERROR: _createGroup: $e");
      _showSnackBar('Erro ao criar grupo.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
        backgroundColor: isError ? Colors.redAccent : const Color(0xFF1A73E8),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Branco Google
      appBar: AppBar(
        title: Text('NOVO GRUPO', 
          style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.5, color: const Color(0xFF1F1F1F))),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Color(0xFF1F1F1F), size: 22),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const SizedBox(height: 30),
              _buildAvatarPicker(),
              const SizedBox(height: 32),
              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: Color(0xFF1F1F1F), fontSize: 15),
                cursorColor: const Color(0xFF1A73E8),
                decoration: _buildInputDecoration('NOME DO GRUPO', Icons.groups_rounded),
                validator: (value) => (value == null || value.trim().isEmpty) ? 'Obrigatório' : null,
              ),
              const SizedBox(height: 32),
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text("SELECIONAR MEMBROS", 
                    style: GoogleFonts.inter(color: Colors.black38, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1)),
                ),
              ),
              const SizedBox(height: 12),
              _buildMemberSelection(),
              const SizedBox(height: 32),
              _buildCreateButton(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarPicker() {
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
              backgroundImage: _groupAvatar != null ? FileImage(_groupAvatar!) : null,
              child: _groupAvatar == null 
                ? const Icon(Icons.add_a_photo_outlined, color: Colors.black26, size: 32) 
                : null,
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(color: Color(0xFF1A73E8), shape: BoxShape.circle),
            child: const Icon(Icons.edit, color: Colors.white, size: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberSelection() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 350),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))
        ]
      ),
      child: _followingList.isEmpty 
        ? Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text("Nenhum contacto encontrado", style: GoogleFonts.inter(color: Colors.black26, fontSize: 13)),
          )
        : ListView.separated(
            shrinkWrap: true,
            physics: const BouncingScrollPhysics(),
            itemCount: _followingList.length,
            separatorBuilder: (_, __) => const Divider(color: Color(0xFFF1F3F4), height: 1, indent: 70),
            itemBuilder: (context, index) {
              final user = _followingList[index];
              final userId = user['id'].toString();
              final isSelected = _selectedMemberIds.contains(userId);
              
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFFF1F3F4),
                  backgroundImage: user['avatar_url'] != null ? NetworkImage(user['avatar_url']) : null,
                  child: user['avatar_url'] == null ? const Icon(Icons.person, size: 22, color: Colors.black26) : null,
                ),
                title: Text(user['username'] ?? 'User', 
                  style: GoogleFonts.inter(color: const Color(0xFF1F1F1F), fontSize: 14, fontWeight: FontWeight.w600)),
                trailing: Icon(
                  isSelected ? Icons.check_circle : Icons.add_circle_outline, 
                  color: isSelected ? const Color(0xFF1A73E8) : Colors.black12,
                  size: 26,
                ),
                onTap: () => _toggleMemberSelection(userId),
              );
            },
          ),
    );
  }

  Widget _buildCreateButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _createGroup,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1A73E8), // Azul Google
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.black12,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          elevation: 0,
        ),
        child: _isLoading 
          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)) 
          : Text('CRIAR GRUPO', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 1)),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.black38, fontSize: 12, fontWeight: FontWeight.bold),
      prefixIcon: Icon(icon, color: Colors.black45, size: 20),
      filled: true,
      fillColor: const Color(0xFFF1F3F4), // Cinza-azulado Google
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF1A73E8), width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(vertical: 18),
    );
  }
}