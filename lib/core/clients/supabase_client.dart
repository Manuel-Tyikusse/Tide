import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/environment.dart';
import '../../core/clients/appwrite_client.dart';

export 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

class TideClient {
  static final TideClient _instance = TideClient._internal();
  factory TideClient() => _instance;

  TideClient._internal() {
    _initializeAuthListener();
  }

  final SupabaseClient client = Supabase.instance.client;
  final AppwriteClient appwrite = AppwriteClient();

  static Future<void> initialize() async {
    try {
      // 1. Inicializa Supabase
      await Supabase.initialize(
        url: Environment.supabaseUrl,
        anonKey: Environment.supabaseAnonKey,
        realtimeClientOptions: const RealtimeClientOptions(
          eventsPerSecond: 10,
        ),
      );
      print("DEBUG: Supabase inicializado com suporte Realtime.");

      // 2. Inicializa Appwrite (Chama o Singleton)
      AppwriteClient();
      print("DEBUG: AppwriteClient pronto para uso.");
      
    } catch (e) {
      print("DEBUG ERROR: Falha na inicialização dos serviços (Supabase/Appwrite): $e");
    }
  }

  // --- 1. ESTADO LOCAL ---
  Map<String, dynamic>? currentUserProfile;
  String? get currentUserId => client.auth.currentUser?.id;
  bool get isAuthenticated => client.auth.currentSession != null;

  void _initializeAuthListener() {
    client.auth.onAuthStateChange.listen((data) {
      print("DEBUG: AuthState alterado para: ${data.event}");
      if (data.event == AuthChangeEvent.signedIn) {
        initializeProfile();
      } else if (data.event == AuthChangeEvent.signedOut) {
        currentUserProfile = null;
      }
    });
  }

  Future<void> initializeProfile() async {
    if (currentUserId == null) return;
    try {
      print("DEBUG: Inicializando perfil para o user: $currentUserId");
      currentUserProfile = await getProfile(currentUserId!);
    } catch (e) {
      print("DEBUG ERROR: initializeProfile: $e");
    }
  }

  // --- 2. AUTENTICAÇÃO ---
  Future<void> signIn({required String email, required String password}) async {
    print("DEBUG: Tentando Login para $email");
    await client.auth.signInWithPassword(email: email, password: password);
    await initializeProfile();
  }

  Future<void> signInWithGoogle() async {
    print("DEBUG: Tentando Login com Google");
    await client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kIsWeb ? null : 'io.supabase.tide://login-callback',
    );
  }

  Future<void> signUp(
      {required String email,
      required String password,
      required String username}) async {
    print("DEBUG: Tentando Criar Conta para $username ($email)");
    final res = await client.auth
        .signUp(email: email, password: password, data: {'username': username});
    if (res.user != null) {
      await client
          .from('profiles')
          .upsert({'id': res.user!.id, 'username': username});
    }
  }

  Future<void> sendPasswordReset({required String email}) async {
    print("DEBUG: Enviando reset de password para $email");
    await client.auth.resetPasswordForEmail(email);
  }

  Future<void> signOut() async {
    print("DEBUG: Realizando SignOut");
    await client.auth.signOut();
    currentUserProfile = null;
  }

  // --- 3. PERFIL ---
  Future<Map<String, dynamic>?> getProfile(String userId) async {
    try {
      print("DEBUG: Buscando perfil para $userId");
      final response = await client
          .rpc('get_profile_details', params: {'p_user_id': userId});
      if (response != null) {
        if (response is Map) return Map<String, dynamic>.from(response);
        if (response is List && response.isNotEmpty)
          return Map<String, dynamic>.from(response.first);
      }
      final recovery =
          await client.from('profiles').select().eq('id', userId).maybeSingle();
      return recovery != null ? Map<String, dynamic>.from(recovery) : null;
    } catch (e) {
      print("DEBUG ERROR: getProfile: $e");
      return null;
    }
  }

  // --- 4. SOCIAL ---
  Future<void> followUser(String targetUserId) async {
    if (currentUserId == null) return;
    print("DEBUG: Seguindo utilizador $targetUserId");
    await client
        .from('followers')
        .insert({'follower_id': currentUserId!, 'following_id': targetUserId});
    await initializeProfile();
  }

  Future<void> unfollowUser(String targetUserId) async {
    if (currentUserId == null) return;
    print("DEBUG: Deixando de seguir utilizador $targetUserId");
    await client
        .from('followers')
        .delete()
        .match({'follower_id': currentUserId!, 'following_id': targetUserId});
    await initializeProfile();
  }

  Future<List<Map<String, dynamic>>> getFollowing(String userId) async {
    print("DEBUG: Buscando lista de quem o user $userId segue");
    final response = await client
        .from('followers')
        .select('following_id, profiles!followers_following_id_fkey(*)')
        .eq('follower_id', userId);
    return List<Map<String, dynamic>>.from(response as List);
  }

  Future<void> likePost(int postId) async {
    if (currentUserId == null) return;
    print("DEBUG: Like no post $postId");
    await client
        .from('likes')
        .upsert({'user_id': currentUserId!, 'post_id': postId});
  }

  Future<void> unlikePost(int postId) async {
    if (currentUserId == null) return;
    print("DEBUG: Unlike no post $postId");
    await client
        .from('likes')
        .delete()
        .match({'post_id': postId, 'user_id': currentUserId!});
  }

  Future<int> getLikeCount(int postId) async {
    try {
      final response = await client
          .from('likes')
          .select('id')
          .eq('post_id', postId)
          .count(CountOption.exact);
      return response.count;
    } catch (e) {
      return 0;
    }
  }

  // --- 5. MEDIA & POSTS ---
  Future<String?> uploadImage(File imageFile, String folderId) async {
    if (currentUserId == null) return null;
    try {
      final fileExtension = imageFile.path.split('.').last;
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}.$fileExtension';

      // Se folderId já vem como 'groups/ID_DO_GRUPO',
      // tenta usar um caminho mais direto para testar:
      final finalPath = '$folderId/$fileName';

      print(
          "DEBUG: Uploading imagem para Bucket: feed_media | Path: $finalPath");

      await client.storage.from('feed_media').upload(
            finalPath,
            imageFile,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );

      final String publicUrl =
          client.storage.from('feed_media').getPublicUrl(finalPath);
      print("DEBUG: Upload concluído. URL: $publicUrl");
      return publicUrl;
    } catch (e) {
      print("DEBUG ERROR: uploadImage falhou detalhadamente: $e");
      return null;
    }
  }

  Future<List<String>> uploadMultipleImages(
      List<File> imageFiles, String folderId) async {
    List<String> urls = [];
    for (var f in imageFiles) {
      final u = await uploadImage(f, folderId);
      if (u != null) urls.add(u);
    }
    return urls;
  }

  /// Cria um post completo vinculando o vídeo do Appwrite
 /// Cria um post completo vinculando o vídeo do Appwrite ao banco do Supabase
  Future<bool> createVideoPost({
    required String videoUrl,
    String? caption,
    String? thumbnailUrl,
    }) async {
      if (currentUserId == null) {
        print("DEBUG ERROR: [POST] createVideoPost - Usuário não autenticado");
        return false;
      }

      try {
        print("DEBUG: [POST] Vinculando vídeo do Appwrite ao Supabase. URL: $videoUrl");

        await client.from('posts').insert({
          'user_id': currentUserId!,
          'caption': caption,
          'media_url': videoUrl, // URL vinda do Appwrite
          'media_type': 'video',
          'thumbnail_url': thumbnailUrl,
          'is_authentic': true, // Captura live
          'created_at': DateTime.now().toIso8601String(),
        });

        print("DEBUG: [SUCCESS] Post de vídeo criado com sucesso no Supabase.");
        return true;
      } catch (e, stacktrace) {
        print("DEBUG ERROR: [POST] createVideoPost falhou: $e");
        print("DEBUG TRACE: $stacktrace");
        return false;
      }
  }

  Future<void> createPost(
      {required String caption,
      required List<String> mediaUrls,
      required String mediaType,
      bool isLiveCapture = true,
      String? thumbnailUrl}) async {
    if (currentUserId == null) return;
    print("DEBUG: Criando post com ${mediaUrls.length} medias");
    await client.from('posts').insert({
      'user_id': currentUserId!,
      'caption': caption,
      'media_url': mediaUrls.isNotEmpty ? mediaUrls.first : null,
      'media_gallery': mediaUrls,
      'media_type': mediaType,
      'thumbnail_url': thumbnailUrl,
    });
  }

  Future<void> deletePost(int postId, List<String> mediaUrls) async {
    print("DEBUG: Deletando post $postId");
    await client.from('posts').delete().eq('id', postId);
  }

  // --- 6. COMENTÁRIOS ---
  Future<List<Map<String, dynamic>>> getCommentsForPost(int postId) async {
    try {
      print(
          "DEBUG: Buscando comentários para o post $postId com detalhes do perfil");

      // Ajuste na query: Buscamos username E avatar_url
      final response = await client
          .from('comments')
          .select('*, profiles!comments_author_fkey(username, avatar_url)')
          .eq('post_id', postId)
          .isFilter('parent_id',
              null) // Opcional: Busca apenas comentários principais primeiro
          .order('created_at', ascending: true);

      final List<dynamic> data = response as List;

      return data.map((item) {
        final map = Map<String, dynamic>.from(item);
        final profiles = map['profiles'] as Map<String, dynamic>?;

        // Injetamos as chaves que a sua UI (CommentTile) agora espera
        map['display_username'] = profiles?['username'] ?? 'Utilizador';
        map['display_avatar'] = profiles?['avatar_url'];

        return map;
      }).toList();
    } catch (e) {
      print("DEBUG ERROR: getCommentsForPost: $e");
      return [];
    }
  }
  // Future<List<Map<String, dynamic>>> getCommentsForPost(int postId) async {
  //   try {
  //     print("DEBUG: Buscando comentários para o post $postId");
  //     final response = await client
  //         .from('comments')
  //         .select('*, author:profiles!comments_author_fkey(id, username, avatar_url)')
  //         .eq('post_id', postId)
  //         .isFilter('parent_id', null)
  //         .order('created_at', ascending: false);

  //     final List<dynamic> data = response as List;
  //     return data.map((e) {
  //       final Map<String, dynamic> comment = Map<String, dynamic>.from(e);
  //       if (comment['author'] == null) {
  //         comment['author'] = {'username': 'utilizador', 'avatar_url': null, 'id': ''};
  //       }
  //       return comment;
  //     }).toList();
  //   } catch (e) {
  //     print("DEBUG ERROR: getCommentsForPost: $e");
  //     return [];
  //   }
  // }

  Future<void> postComment(int postId, String content) async {
    if (currentUserId == null) return;
    print("DEBUG: Postando comentário no post $postId");
    await client.from('comments').insert(
        {'post_id': postId, 'user_id': currentUserId!, 'content': content});
  }

  Future<void> replyToComment(int postId, String content, int parentId) async {
    if (currentUserId == null) return;
    print("DEBUG: Respondendo ao comentário $parentId");
    await client.from('comments').insert({
      'post_id': postId,
      'user_id': currentUserId!,
      'content': content,
      'parent_id': parentId
    });
  }

  Future<void> likeComment(int commentId) async {
    if (currentUserId == null) return;
    await client
        .from('comment_likes')
        .insert({'comment_id': commentId, 'user_id': currentUserId!});
  }

  Future<void> unlikeComment(int commentId) async {
    if (currentUserId == null) return;
    await client
        .from('comment_likes')
        .delete()
        .match({'comment_id': commentId, 'user_id': currentUserId!});
  }

  // --- 7. CHAT & MENSAGENS (Fluidez Realtime) ---

  // Stream de mensagens para o chat ser instantâneo
  Stream<List<Map<String, dynamic>>> getMessagesStream(int roomId) {
    print("DEBUG: Escutando Stream de mensagens para sala $roomId");
    return client
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .eq('room_id', roomId)
        .order('created_at', ascending: true);
  }

  // Stream para a ChatListScreen (Reatividade na lista de conversas)
  Stream<List<Map<String, dynamic>>> getChatRoomsStream() {
    if (currentUserId == null) return Stream.value([]);
    print(
        "DEBUG: Escutando Stream de salas de chat para o user $currentUserId");

    // Escutamos a tabela de participantes para saber quando o user entra/sai de chats
    return client
        .from('chat_participants')
        .stream(primaryKey: ['room_id', 'user_id'])
        .eq('user_id', currentUserId!)
        .asyncMap((event) async {
          return await getChatRoomsForUser(); // Recarrega os detalhes quando o stream detecta mudança
        });
  }

  // Stream para que o ponto vermelho das notificações desapareça instantaneamente
  Stream<int> getUnreadMessagesStream() {
    if (currentUserId == null) return Stream.value(0);
    print("DEBUG: Stream de contagem global de mensagens não lidas otimizado");
    return client.from('chat_messages').stream(primaryKey: ['id'])
        // Filtre por sender_id no stream para reduzir processamento
        .map((data) => data
            .where((row) =>
                row['sender_id'] != currentUserId && row['is_read'] == false)
            .length);
  }

  Stream<int> getUnreadNotificationsStream() {
    if (currentUserId == null) return Stream.value(0);
    print("DEBUG: Stream de notificações não lidas ativado");
    return client.from('notifications').stream(primaryKey: ['id']).map((data) =>
        data
            .where((row) =>
                row['receiver_id'] == currentUserId && row['is_read'] == false)
            .length);
  }

  Future<void> markMessagesAsRead(int roomId) async {
    final userId = currentUserId;
    if (userId == null) return;

    try {
      print("DEBUG: Marcando mensagens da sala $roomId como lidas");

      // Atualiza no banco de dados
      await client
          .from('chat_messages')
          .update({'is_read': true})
          .eq('room_id', roomId)
          .eq('is_read', false)
          .neq('sender_id', userId); // Só mensagens que eu recebi

      print("DEBUG: Status de leitura atualizado com sucesso.");
    } catch (e) {
      print("DEBUG ERROR: markMessagesAsRead falhou: $e");
    }
  }

  Future<void> sendMessage(int roomId, String content) async {
    if (currentUserId == null || content.trim().isEmpty) return;
    print("DEBUG: Enviando mensagem para sala $roomId");
    await client.from('chat_messages').insert({
      'room_id': roomId,
      'sender_id': currentUserId!,
      'content': content.trim(),
      'is_read': false
    });
  }

  Future<int> createOrGetPrivateChat(String otherUserId) async {
    print("DEBUG: Criando/Buscando chat privado com $otherUserId");
    final response = await client.rpc('create_or_get_chat_room',
        params: {'p_other_user_id': otherUserId});
    return (response as num).toInt();
  }

  Future<void> createGroup(String name) async {
    if (currentUserId == null) return;
    try {
      print("DEBUG: Criando grupo $name");
      final room = await client
          .from('chat_rooms')
          .insert({
            'group_name': name,
            'is_group': true,
            'created_by': currentUserId
          })
          .select()
          .single();

      await client.from('chat_participants').insert(
          {'room_id': room['id'], 'user_id': currentUserId, 'role': 'admin'});
    } catch (e) {
      print("DEBUG ERROR: createGroup falhou: $e");
    }
  }

  Future<Map<String, dynamic>> createGroupChat(
      String name, File? avatarFile, List<String> memberIds) async {
    if (currentUserId == null) throw Exception("Autenticação necessária");

    try {
      print("DEBUG: Criando grupo '$name'...");
      final room = await client
          .from('chat_rooms')
          .insert({
            'group_name': name,
            'is_group': true,
            'created_by': currentUserId
          })
          .select()
          .single();

      final roomId = room['id'];

      if (avatarFile != null) {
        print("DEBUG: Iniciando upload de avatar para o grupo $roomId");
        // Importante: Usar uma pasta específica para avatares
        final url = await uploadImage(avatarFile, 'group_avatars/$roomId');

        if (url != null) {
          print(
              "DEBUG: Upload concluído. URL: $url. Atualizando chat_rooms...");
          await client
              .from('chat_rooms')
              .update({'group_avatar_url': url}).eq('id', roomId);
          room['group_avatar_url'] = url; // Atualiza o objeto local
        } else {
          print("DEBUG ERROR: O método uploadImage retornou NULL");
        }
      }

      final List<Map<String, dynamic>> participants = [
        {'room_id': roomId, 'user_id': currentUserId, 'role': 'admin'}
      ];
      for (var id in memberIds) {
        participants.add({'room_id': roomId, 'user_id': id, 'role': 'member'});
      }

      await client.from('chat_participants').insert(participants);
      return Map<String, dynamic>.from(room);
    } catch (e) {
      print("DEBUG ERROR: createGroupChat falhou: $e");
      rethrow;
    }
  }

  Future<void> addMemberToGroup(int roomId, String userId) async {
    try {
      print("DEBUG: Adicionando membro $userId ao grupo $roomId");
      await client
          .from('chat_participants')
          .insert({'room_id': roomId, 'user_id': userId, 'role': 'member'});
    } catch (e) {
      print("DEBUG ERROR: addMemberToGroup: $e");
    }
  }

  Future<List<Map<String, dynamic>>> getChatRoomsForUser() async {
    if (currentUserId == null) return [];
    try {
      print(
          "DEBUG: Buscando salas exclusivas para o utilizador: $currentUserId");

      final participantRooms = await client
          .from('chat_participants')
          .select('room_id')
          .eq('user_id', currentUserId!);

      final List<dynamic> roomIds =
          (participantRooms as List).map((p) => p['room_id']).toList();
      if (roomIds.isEmpty) return [];

      final response = await client
          .from('chat_rooms')
          .select(
              '*, chat_participants(*, profiles(*)), chat_messages(content, created_at, sender_id, is_read)')
          .inFilter('id', roomIds)
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> rooms =
          (response as List).map((e) => Map<String, dynamic>.from(e)).toList();

      for (var room in rooms) {
        final messages = room['chat_messages'] as List? ?? [];
        room['unread_count'] = messages
            .where(
                (m) => m['sender_id'] != currentUserId && m['is_read'] == false)
            .length;
      }

      rooms.sort((a, b) {
        final messagesA = a['chat_messages'] as List;
        final messagesB = b['chat_messages'] as List;
        final DateTime timeA = messagesA.isNotEmpty
            ? DateTime.parse(messagesA.last['created_at'])
            : DateTime.parse(a['created_at']);
        final DateTime timeB = messagesB.isNotEmpty
            ? DateTime.parse(messagesB.last['created_at'])
            : DateTime.parse(b['created_at']);
        return timeB.compareTo(timeA);
      });

      return rooms;
    } catch (e) {
      print("DEBUG ERROR: getChatRoomsForUser: $e");
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAvailableUsers() async {
    if (currentUserId == null) return [];
    try {
      print("DEBUG: Buscando utilizadores disponíveis");
      final response =
          await client.from('profiles').select().neq('id', currentUserId!);
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      print("DEBUG ERROR: getAvailableUsers: $e");
      return [];
    }
  }

  // --- 8. GESTÃO AVANÇADA DE GRUPOS ---

  Future<void> updateGroupProfile(
      {required int roomId,
      String? name,
      String? description,
      File? avatarFile}) async {
    try {
      final Map<String, dynamic> updates = {};
      if (name != null) updates['group_name'] = name;
      if (description != null) updates['description'] = description;
      if (avatarFile != null) {
        final url = await uploadImage(avatarFile, 'groups/$roomId');
        if (url != null) updates['group_avatar_url'] = url;
      }
      if (updates.isNotEmpty) {
        await client.from('chat_rooms').update(updates).eq('id', roomId);
        print("DEBUG: Grupo $roomId atualizado");
      }
    } catch (e) {
      print("DEBUG ERROR: updateGroupProfile: $e");
    }
  }

  Future<void> removeMemberFromGroup(int roomId, String userId) async {
    try {
      print("DEBUG: Removendo utilizador $userId do grupo $roomId");
      await client
          .from('chat_participants')
          .delete()
          .match({'room_id': roomId, 'user_id': userId});
    } catch (e) {
      print("DEBUG ERROR: removeMemberFromGroup: $e");
    }
  }

  Future<void> leaveGroup(int roomId) async {
    if (currentUserId == null) return;
    try {
      print("DEBUG: Utilizador saindo do grupo $roomId");
      await client
          .from('chat_participants')
          .delete()
          .match({'room_id': roomId, 'user_id': currentUserId!});
    } catch (e) {
      print("DEBUG ERROR: leaveGroup: $e");
    }
  }

  Future<bool> isUserAdmin(int roomId) async {
    if (currentUserId == null) return false;
    try {
      final response = await client
          .from('chat_participants')
          .select('role')
          .match({'room_id': roomId, 'user_id': currentUserId!}).maybeSingle();
      return response != null && response['role'] == 'admin';
    } catch (e) {
      return false;
    }
  }
  // --- NOVOS MÉTODOS PARA ADICIONAR AO TIDECLIENT ---

  /// Marca as mensagens de uma sala como lidas, exceto as enviadas pelo próprio user.
  // No seu TideClient
  Future<void> deleteRecentSearch(String searchId) async {
    try {
      print("DEBUG: Deletando pesquisa recente ID: $searchId");
      await client.from('recent_searches').delete().eq('id', searchId);
    } catch (e) {
      print("DEBUG ERROR: deleteRecentSearch: $e");
      rethrow;
    }
  }

  Future<void> clearAllRecentSearches() async {
    final userId = currentUserId;
    if (userId == null) return;
    try {
      print(
          "DEBUG: Limpando todo o histórico de buscas para o usuário $userId");
      await client.from('recent_searches').delete().eq('user_id', userId);
    } catch (e) {
      print("DEBUG ERROR: clearAllRecentSearches: $e");
      rethrow;
    }
  }
}
