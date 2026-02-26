import 'package:flutter/foundation.dart';
import 'package:tide/core/clients/supabase_client.dart';

class AlgorithmService {
  static final AlgorithmService _instance = AlgorithmService._internal();
  factory AlgorithmService() => _instance;
  AlgorithmService._internal();

  final TideClient _client = TideClient();

  /// Obtém o feed principal com lógica de ranking e paginação
  Future<List<Map<String, dynamic>>> getRankedFeed({int limit = 20, int offset = 0}) async {
    try {
      // Passamos o currentUserId para o RPC saber se o user logado deu like
      final response = await _client.client.rpc(
        'get_ranked_feed',
        params: {
          'p_limit': limit,
          'p_offset': offset,
          'p_user_id': _client.currentUserId, 
        },
      );

      if (response == null) return await _getFallbackFeed(limit, offset);
      
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      debugPrint("Erro AlgorithmService (getRankedFeed): $e");
      return await _getFallbackFeed(limit, offset);
    }
  }

  /// Fallback caso o RPC falhe: busca os posts mais recentes
  Future<List<Map<String, dynamic>>> _getFallbackFeed(int limit, int offset) async {
    try {
      // CORREÇÃO: A query de fallback foi corrigida para resolver a ambiguidade.
      // A relação entre posts e perfis foi especificada, tal como nos outros ecrãs.
      final response = await _client.client
          .from('posts')
          .select('*, profiles!posts_user_id_fkey(*)') // CORREÇÃO APLICADA
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
      
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      debugPrint("Erro crítico no Fallback Feed: $e");
      return [];
    }
  }

  /// Atualiza o engagement (Views, Likes, Shares) para influenciar o ranking
  Future<void> updateEngagement(int postId, {
    bool isView = false, 
    bool? hasLiked,
    bool isShare = false,
  }) async {
    try {
      double increment = 0.0;

      // Pesos do Algoritmo
      if (isView) increment += 0.1; // Visualização vale pouco, mas conta
      if (hasLiked != null) increment += hasLiked ? 2.0 : -2.0; // Likes pesam muito
      if (isShare) increment += 5.0; // Partilha é o sinal mais forte de interesse

      if (increment != 0) {
        await _client.client.rpc('update_engagement_score', params: {
          'p_post_id': postId,
          'p_increment': increment,
        });
      }
    } catch (e) {
      // Falha silenciosa para não interromper a experiência do user
      debugPrint("Engage Update Silent Error: $e");
    }
  }
}
