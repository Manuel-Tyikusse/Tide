import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:tide/core/clients/appwrite_client.dart';
import 'package:tide/core/clients/supabase_client.dart';
import 'dart:developer' as developer;

class MediaService {
  final AppwriteClient _appwriteClient = AppwriteClient();
  final TideClient _supabaseClient = TideClient();

  Future<String?> uploadMedia(File file, {String? postId}) async {
    // 1. Validar se o ficheiro existe antes de tentar o upload
    if (!await file.exists()) {
      developer.log("Erro: Ficheiro não existe em ${file.path}", name: 'MediaService.uploadMedia');
      return null;
    }

    final fileExtension = path.extension(file.path).toLowerCase();

    // 2. Lógica de Upload Híbrida
    if (_isVideo(fileExtension)) {
      developer.log("Upload de vídeo detetado (Appwrite)", name: 'MediaService.uploadMedia');
      return await _appwriteClient.uploadVideo(file);
    } 
    
    if (_isImage(fileExtension)) {
      developer.log("Upload de imagem detetado (Supabase)", name: 'MediaService.uploadMedia');
      
      // Se o PostPreview não enviou um postId, geramos um baseado no tempo
      final folderId = postId ?? DateTime.now().millisecondsSinceEpoch.toString();
      
      // Passa o ficheiro e o ID da pasta (postId) para o cliente Supabase
      return await _supabaseClient.uploadImage(file, folderId);
    }

    developer.log("Tipo de ficheiro não suportado: $fileExtension", name: 'MediaService.uploadMedia', level: 900);
    return null;
  }

  // Suporte alargado para extensões de vídeo comuns
  bool _isVideo(String extension) {
    return ['.mp4', '.mov', '.avi', '.mkv', '.webm'].contains(extension);
  }

  // Suporte para extensões de imagem, incluindo formatos de câmera e web
  bool _isImage(String extension) {
    return ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.heic', '.heif'].contains(extension);
  }
}
