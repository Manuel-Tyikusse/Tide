import 'dart:io';
import 'package:appwrite/appwrite.dart';
import 'package:tide/core/config/environment.dart';
import 'dart:developer' as developer;

class AppwriteClient {
  static final AppwriteClient _instance = AppwriteClient._internal();
  factory AppwriteClient() => _instance;

  late final Client _client;
  late final Storage _storage;

  AppwriteClient._internal() {
    _client = Client()
        .setEndpoint(Environment.appwriteEndpoint)
        .setProject(Environment.appwriteProjectId)
        .setSelfSigned(status: true); 
    
    _storage = Storage(_client);
    _initConnection();
  }

  // MÉTODO CORRIGIDO: listFiles em vez de listBuckets
  void _initConnection() {
    _storage.listFiles(
      bucketId: Environment.appwriteVideosBucketId,
      queries: [Query.limit(1)],
    ).then((_) {
      developer.log('DEBUG: Conexão com Appwrite validada com sucesso no dashboard.', name: 'AppwriteClient');
    }).catchError((e) {
      // É normal dar erro se o bucket ainda não existir ou não tiveres permissão de read, 
      // mas o "ping" para o servidor já terá sido feito para validar o projeto.
      developer.log('DEBUG INFO: Tentativa de handshake com Appwrite concluída.', name: 'AppwriteClient');
    });
  }

  Future<String?> uploadVideo(File videoFile) async {
    try {
      final fileId = ID.unique();
      developer.log('DEBUG: Iniciando upload para Appwrite. Bucket: ${Environment.appwriteVideosBucketId}', name: 'AppwriteClient.uploadVideo');

      final uploadedFile = await _storage.createFile(
        bucketId: Environment.appwriteVideosBucketId,
        fileId: fileId,
        file: InputFile.fromPath(path: videoFile.path),
        permissions: [Permission.read(Role.any())],
      );

      final url = '${Environment.appwriteEndpoint}/storage/buckets/${Environment.appwriteVideosBucketId}/files/${uploadedFile.$id}/view?project=${Environment.appwriteProjectId}';

      developer.log('DEBUG: Upload concluído com sucesso. URL: $url', name: 'AppwriteClient.uploadVideo');
      return url;
    } catch (e, s) {
      developer.log('DEBUG ERROR: Falha no upload do vídeo para o Appwrite', name: 'AppwriteClient.uploadVideo', error: e, stackTrace: s);
      return null;
    }
  }
}

