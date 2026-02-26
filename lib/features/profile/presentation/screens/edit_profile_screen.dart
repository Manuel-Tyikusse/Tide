import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/clients/supabase_client.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();
  
  bool _isLoading = true;
  bool _isSaving = false;
  File? _selectedImage;
  String? _currentAvatarUrl;
  
  late final String _myId;

  @override
  void initState() {
    super.initState();
    _myId = TideClient().currentUserId ?? '';
    print("DEBUG: EditProfileScreen inicializada para o utilizador: $_myId");
    
    if (_myId.isEmpty) {
      print("DEBUG ERROR: ID do utilizador vazio, fechando ecrã.");
      WidgetsBinding.instance.addPostFrameCallback((_) => Navigator.pop(context));
    } else {
      _loadProfile();
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      print("DEBUG: Carregando dados do perfil do Supabase...");
      final data = await TideClient().client.from('profiles').select().eq('id', _myId).single();
      
      if (mounted) {
        setState(() {
          _usernameController.text = data['username'] ?? '';
          _bioController.text = data['bio'] ?? '';
          _currentAvatarUrl = data['avatar_url'];
          _isLoading = false;
        });
        print("DEBUG: Perfil carregado com sucesso.");
      }
    } catch (e) {
      print("DEBUG ERROR: _loadProfile: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    print("DEBUG: Abrindo galeria para seleção de imagem...");
    
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    
    if (pickedFile != null && mounted) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
      print("DEBUG: Imagem selecionada: ${pickedFile.path}");
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate() || _isSaving) return;

    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();
    print("DEBUG: Iniciando processo de salvamento do perfil...");

    try {
      String? newAvatarUrl;

      if (_selectedImage != null) {
        final bytes = await _selectedImage!.readAsBytes();
        final ext = _selectedImage!.path.split('.').last;
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
        final path = 'avatars/$_myId/$fileName';
        
        print("DEBUG: Fazendo upload da nova imagem para storage: $path");
        
        await TideClient().client.storage.from('feed_media').uploadBinary(
          path, 
          bytes,
          fileOptions: FileOptions(upsert: true, contentType: 'image/$ext'),
        );
        
        newAvatarUrl = TideClient().client.storage.from('feed_media').getPublicUrl(path);
        print("DEBUG: Upload concluído. Nova URL: $newAvatarUrl");
      }

      final updates = {
        'username': _usernameController.text.trim(),
        'bio': _bioController.text.trim(),
        if (newAvatarUrl != null) 'avatar_url': newAvatarUrl,
        'updated_at': DateTime.now().toIso8601String(),
      };

      print("DEBUG: Atualizando tabela 'profiles' no Supabase...");
      await TideClient().client.from('profiles').update(updates).eq('id', _myId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perfil atualizado com sucesso!'), 
            backgroundColor: Color(0xFF1A73E8),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      print("DEBUG ERROR: _saveProfile: $e");
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao guardar as alterações.'), 
            backgroundColor: Colors.redAccent,
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
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        title: Text('EDITAR PERFIL', 
          style: GoogleFonts.inter(
            fontSize: 14, 
            fontWeight: FontWeight.w900, 
            color: const Color(0xFF1F1F1F), 
            letterSpacing: 1.2
          )
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Color(0xFF1F1F1F), size: 24),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: TextButton(
              onPressed: _saveProfile,
              child: _isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1A73E8)))
                  : Text('CONCLUIR', 
                      style: GoogleFonts.inter(
                        color: const Color(0xFF1A73E8), 
                        fontWeight: FontWeight.w800, 
                        fontSize: 14
                      )
                    ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(color: Colors.black.withOpacity(0.05), height: 1),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1A73E8), strokeWidth: 3))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const SizedBox(height: 40),
                    _buildAvatarSection(),
                    const SizedBox(height: 48),
                    _buildInput(
                      controller: _usernameController,
                      label: 'NOME DE UTILIZADOR',
                      validator: (v) => v!.isEmpty ? 'O nome é obrigatório' : null,
                    ),
                    const SizedBox(height: 32),
                    _buildInput(
                      controller: _bioController,
                      label: 'BIO',
                      maxLines: 3,
                      hint: 'Conta algo sobre ti...',
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildAvatarSection() {
    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black.withOpacity(0.05), width: 2),
              ),
              child: CircleAvatar(
                radius: 54,
                backgroundColor: const Color(0xFFF1F3F4),
                backgroundImage: _selectedImage != null
                    ? FileImage(_selectedImage!)
                    : (_currentAvatarUrl != null ? NetworkImage(_currentAvatarUrl!) : null) as ImageProvider?,
                child: (_selectedImage == null && _currentAvatarUrl == null)
                    ? const Icon(Icons.person, size: 48, color: Colors.black12)
                    : null,
              ),
            ),
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFF1A73E8),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: _pickImage,
          child: Text(
            'Alterar foto de perfil',
            style: GoogleFonts.inter(
              color: const Color(0xFF1A73E8), 
              fontWeight: FontWeight.w700, 
              fontSize: 14
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
    String? hint,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: Colors.black54, 
            fontSize: 11, 
            fontWeight: FontWeight.w800, 
            letterSpacing: 0.8
          ),
        ),
        TextFormField(
          controller: controller,
          validator: validator,
          maxLines: maxLines,
          style: const TextStyle(color: Color(0xFF1F1F1F), fontSize: 16, fontWeight: FontWeight.w500),
          cursorColor: const Color(0xFF1A73E8),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.black12, fontSize: 15),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black.withOpacity(0.1))),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF1A73E8), width: 2)),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ],
    );
  }
}
