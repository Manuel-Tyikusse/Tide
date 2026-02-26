import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tide/core/clients/supabase_client.dart';
import 'package:tide/core/clients/appwrite_client.dart'; // Import necessário

class PostPreviewScreen extends StatefulWidget {
  final List<File> mediaFiles; 

  const PostPreviewScreen({
    super.key, 
    required this.mediaFiles,
  });

  @override
  State<PostPreviewScreen> createState() => _PostPreviewScreenState();
}

class _PostPreviewScreenState extends State<PostPreviewScreen> {
  final TideClient _client = TideClient();
  final AppwriteClient _appwrite = AppwriteClient(); // Instância do Appwrite
  final TextEditingController _captionController = TextEditingController();
  final PageController _pageController = PageController();
  
  bool _isUploading = false;
  int _currentPage = 0;

  @override
  void dispose() {
    _captionController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // Auxiliar para identificar o tipo de mídia
  bool _isVideo(File file) {
    final path = file.path.toLowerCase();
    return path.endsWith('.mp4') || path.endsWith('.mov') || path.endsWith('.avi');
  }

  Future<void> _uploadPost() async {
    if (_isUploading || widget.mediaFiles.isEmpty) return;

    setState(() => _isUploading = true);
    print("DEBUG: Iniciando processo de publicação...");

    try {
      final firstFile = widget.mediaFiles.first;
      final isVideo = _isVideo(firstFile);

      if (isVideo) {
        // --- FLUXO VÍDEO (APPWRITE + SUPABASE) ---
        print("DEBUG: Upload de VÍDEO detectado. Enviando para Appwrite...");
        
        final String? videoUrl = await _appwrite.uploadVideo(firstFile);
        
        if (videoUrl == null) throw Exception('Falha ao carregar vídeo para o Appwrite.');

        print("DEBUG: Vídeo no Appwrite com sucesso. Vinculando ao Supabase...");
        
        final success = await _client.createVideoPost(
          videoUrl: videoUrl,
          caption: _captionController.text.trim(),
        );

        if (!success) throw Exception('Falha ao vincular vídeo no banco de dados.');

      } else {
        // --- FLUXO IMAGEM (SUPABASE STORAGE + SUPABASE DB) ---
        final String folderId = 'posts/${DateTime.now().millisecondsSinceEpoch}';
        print("DEBUG: Upload de IMAGEM detectado. Enviando para Supabase em $folderId");

        final List<String> uploadedUrls = await _client.uploadMultipleImages(
          widget.mediaFiles, 
          folderId,
        );

        if (uploadedUrls.isEmpty) throw Exception('Falha ao carregar imagens.');

        await _client.createPost(
          caption: _captionController.text.trim(),
          mediaUrls: uploadedUrls,
          mediaType: 'image',
          thumbnailUrl: uploadedUrls.first,
        );
      }

      // --- LIMPEZA DE PRIVACIDADE ---
      print("DEBUG: Limpando ficheiros locais temporários...");
      for (var file in widget.mediaFiles) {
        if (await file.exists()) {
          await file.delete();
        }
      }

      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        _showNotification("Publicado com sucesso!", isError: false);
      }
    } catch (e) {
      debugPrint("DEBUG ERROR (Upload): $e");
      if (mounted) _showNotification("Erro ao publicar: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showNotification(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message, 
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.white)
        ),
        backgroundColor: isError ? Colors.redAccent : const Color(0xFF1A73E8),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), 
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FA),
        elevation: 0,
        centerTitle: true,
        title: Text(
          "REVER PUBLICAÇÃO", 
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w900, 
            fontSize: 11, 
            letterSpacing: 2, 
            color: const Color(0xFF1F1F1F)
          )
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF1F1F1F), size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (!_isUploading)
            TextButton(
              onPressed: _uploadPost,
              child: Text(
                "PARTILHAR", 
                style: GoogleFonts.inter(
                  color: const Color(0xFF1A73E8), 
                  fontWeight: FontWeight.w900, 
                  fontSize: 13
                )
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                PageView.builder(
                  controller: _pageController,
                  itemCount: widget.mediaFiles.length,
                  onPageChanged: (index) => setState(() => _currentPage = index),
                  itemBuilder: (context, index) {
                    final file = widget.mediaFiles[index];
                    final isVideo = _isVideo(file);

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: isVideo ? Colors.black : Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4)
                          )
                        ],
                      ),
                      child: isVideo 
                        ? const Center(
                            child: Icon(Icons.play_circle_outline, color: Colors.white, size: 60)
                          )
                        : Image.file(
                            file, 
                            fit: BoxFit.cover,
                          ),
                    );
                  },
                ),
                
                Positioned(
                  top: 25,
                  left: 25,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.camera_alt, color: Colors.white, size: 14),
                        const SizedBox(width: 8),
                        Text(
                          "CAMERA LIVE", 
                          style: GoogleFonts.inter(
                            color: Colors.white, 
                            fontSize: 10, 
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5
                          )
                        ),
                      ],
                    ),
                  ),
                ),

                if (widget.mediaFiles.length > 1)
                  Padding(
                    padding: const EdgeInsets.all(25.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        "${_currentPage + 1} / ${widget.mediaFiles.length}",
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          Container(
            padding: EdgeInsets.only(
              left: 24, right: 24, top: 24, 
              bottom: MediaQuery.of(context).viewInsets.bottom + 30
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              boxShadow: [
                BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -5))
              ]
            ),
            child: TextField(
              controller: _captionController,
              enabled: !_isUploading,
              style: const TextStyle(color: Color(0xFF1F1F1F), fontSize: 16),
              maxLines: null,
              decoration: InputDecoration(
                hintText: "Escreve uma legenda...",
                hintStyle: const TextStyle(color: Colors.black26, fontSize: 15),
                filled: true,
                fillColor: const Color(0xFFF1F3F4), 
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none
                ),
                contentPadding: const EdgeInsets.all(16),
                suffixIcon: _isUploading 
                    ? const SizedBox(
                        width: 24, 
                        height: 24, 
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5, 
                            color: Color(0xFF1A73E8)
                          )
                        )
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}