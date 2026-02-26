import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/clients/supabase_client.dart';
import 'add_participants_screen.dart';
import 'group_settings_screen.dart';

class ChatRoomScreen extends StatefulWidget {
  final String roomId;
  final String? chatName;

  const ChatRoomScreen({super.key, required this.roomId, this.chatName});

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final _client = TideClient();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  
  // Guardamos o Stream numa variável para evitar que o StreamBuilder 
  // reinicie sempre que o widget sofrer um rebuild (como quando o teclado abre)
  late Stream<List<Map<String, dynamic>>> _messageStream;

  bool _isGroup = false;
  bool _isAdmin = false;
  bool _isSendingImage = false;
  List<String> _currentParticipantIds = [];
  Map<String, dynamic>? _fullRoomData;

  @override
void initState() {
  super.initState();
  final intRoomId = int.tryParse(widget.roomId) ?? 0;
  
  // 1. Inicializa o Stream
  _messageStream = _client.getMessagesStream(intRoomId);
  
  // 2. Escuta o Stream para marcar novas mensagens como lidas instantaneamente
  _messageStream.listen((messages) {
    if (mounted && messages.isNotEmpty) {
      // Verifica se a última mensagem não foi enviada por mim e não está lida
      final lastMessage = messages.last;
      if (lastMessage['sender_id'] != _client.currentUserId && lastMessage['is_read'] == false) {
        _client.markMessagesAsRead(intRoomId);
        print("DEBUG: Nova mensagem recebida. Atualizando status para lido.");
      }
    }
  });

  _loadRoomDetails();
  _client.markMessagesAsRead(intRoomId);
}

  Future<void> _loadRoomDetails() async {
    try {
      final room = await _client.client
          .from('chat_rooms')
          .select('*, chat_participants(*, profiles(*))')
          .eq('id', widget.roomId)
          .single();

      if (mounted) {
        setState(() {
          _fullRoomData = room;
          _isGroup = room['is_group'] ?? false;
          final participants = room['chat_participants'] as List;
          _currentParticipantIds = participants.map((p) => p['user_id'].toString()).toList();
          final myParticipant = participants.firstWhere(
            (p) => p['user_id'] == _client.currentUserId,
            orElse: () => null,
          );
          _isAdmin = myParticipant != null && myParticipant['role'] == 'admin';
        });
      }
    } catch (e) {
      debugPrint("DEBUG ERROR: _loadRoomDetails: $e");
    }
  }

  // Localização: Dentro da classe _ChatRoomScreenState, antes do método _sendMessage
Future<void> _sendCameraImage() async {
  final ImagePicker picker = ImagePicker();
    
    // O ImagePicker guarda a foto no diretório de Cache temporário da app
    final XFile? photo = await picker.pickImage(
      source: ImageSource.camera, 
      imageQuality: 70,
    );
    
    if (photo == null) return;

    setState(() => _isSendingImage = true);
    
    final File imageFile = File(photo.path);

    try {
      final intRoomId = int.tryParse(widget.roomId);
      if (intRoomId == null) return;

      print("DEBUG: Iniciando upload de imagem privada...");
      
      // Faz o upload para o Supabase
      final String? imageUrl = await _client.uploadImage(
        imageFile, 
        'chat_media/${widget.roomId}'
      );

      if (imageUrl != null) {
        await _client.sendMessage(intRoomId, imageUrl);
        _scrollToBottom();
        
        // --- O PULO DO GATO PARA PRIVACIDADE ---
        // Apagamos o ficheiro do armazenamento do telemóvel assim que o upload termina
        if (await imageFile.exists()) {
          await imageFile.delete();
          print("DEBUG: Ficheiro local removido. Privacidade garantida.");
        }
      }
    } catch (e) {
      debugPrint("DEBUG ERROR: _sendCameraImage: $e");
    } finally {
      if (mounted) setState(() => _isSendingImage = false);
    }
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    _messageController.clear();
    try {
      final intRoomId = int.tryParse(widget.roomId);
      if (intRoomId == null) return;
      await _client.sendMessage(intRoomId, text);
      _scrollToBottom();
    } catch (e) {
      debugPrint("DEBUG ERROR: _sendMessage: $e");
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(0.0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _client.currentUserId;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      // Impede que os widgets se redimensionem de forma agressiva ao abrir o teclado
      resizeToAvoidBottomInset: true, 
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Text(widget.chatName?.toUpperCase() ?? "CHAT", 
            style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.2, color: const Color(0xFF1F1F1F))),
        centerTitle: true,
        actions: [
          if (_isGroup) ...[
            IconButton(
              icon: const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF1A73E8)),
              onPressed: () async {
                final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => 
                  AddParticipantsScreen(roomId: widget.roomId, existingParticipantIds: _currentParticipantIds)));
                if (result == true) _loadRoomDetails();
              },
            ),
            if (_isAdmin && _fullRoomData != null)
              IconButton(
                icon: const Icon(Icons.settings_outlined, color: Colors.black54),
                onPressed: () async {
                  final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => 
                    GroupSettingsScreen(roomData: _fullRoomData!)));
                  if (result == true) _loadRoomDetails();
                },
              ),
          ]
        ],
      ),
      body: Column(
        children: [
          if (_isSendingImage)
            const LinearProgressIndicator(backgroundColor: Color(0xFFF1F3F4), color: Color(0xFF1A73E8), minHeight: 2),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _messageStream, // Usando a variável fixa para evitar reload
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text("Erro: ${snapshot.error}"));
                if (snapshot.connectionState == ConnectionState.waiting) 
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF1A73E8)));

                final messages = snapshot.data ?? [];
                final sortedMessages = List<Map<String, dynamic>>.from(messages)
                  ..sort((a, b) => b['created_at'].compareTo(a['created_at']));

                if (sortedMessages.isEmpty) return _buildEmptyChat();

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  itemCount: sortedMessages.length,
                  itemBuilder: (context, index) {
                    final msg = sortedMessages[index];
                    final isMe = msg['sender_id'] == currentUserId;
                    final bool isImage = msg['content'].toString().contains('feed_media') || 
                                         msg['content'].toString().contains('chat_media');

                    return _buildMessageBubble(msg, isMe, isImage);
                  },
                );
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildEmptyChat() {
    return Center(child: Text("Diz olá a ${widget.chatName ?? 'este grupo'}!", style: GoogleFonts.inter(color: Colors.black26, fontSize: 13)));
  }

  // Localização: Dentro da classe _ChatRoomScreenState, logo abaixo do método _buildEmptyChat
  Widget _buildMessageBubble(Map<String, dynamic> msg, bool isMe, bool isImage) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: isImage ? const EdgeInsets.all(2) : const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFF1A73E8) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isMe ? 20 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 5,
              offset: const Offset(0, 2),
            )
          ],
        ),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (isImage)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  msg['content'],
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 200,
                      width: 200,
                      color: Colors.black12,
                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1A73E8))),
                    );
                  },
                ),
              )
            else
              Text(
                msg['content'] ?? "",
                style: GoogleFonts.inter(
                  color: isMe ? Colors.white : const Color(0xFF1F1F1F),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  msg['created_at'] != null 
                      ? DateFormat('HH:mm').format(DateTime.parse(msg['created_at'])) 
                      : "--:--",
                  style: TextStyle(
                    color: isMe ? Colors.white70 : Colors.black38, 
                    fontSize: 9, 
                    fontWeight: FontWeight.w700
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.done_all_rounded, 
                    size: 13, 
                    // Se a mensagem foi lida, fica azul claro, senão fica branco suave
                    color: (msg['is_read'] == true) ? Colors.lightBlueAccent : Colors.white70,
                  ),
                ]
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFEEEEEE), width: 1))),
      child: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end, // Alinha os ícones ao fundo enquanto o texto cresce
          children: [
            IconButton(
              onPressed: _isSendingImage ? null : _sendCameraImage,
              icon: const Icon(Icons.camera_alt_outlined, color: Color(0xFF1A73E8), size: 26),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: TextField(
                controller: _messageController,
                // --- AJUSTES PARA MÚLTIPLAS LINHAS ---
                keyboardType: TextInputType.multiline,
                minLines: 1,
                maxLines: 5, // O campo cresce até 5 linhas antes de fazer scroll interno
                textInputAction: TextInputAction.newline, // Teclado exibe o botão "Enter" em vez de "Concluir"
                style: const TextStyle(color: Color(0xFF1F1F1F), fontSize: 15),
                decoration: InputDecoration(
                  hintText: "Mensagem...",
                  hintStyle: const TextStyle(color: Colors.black26, fontSize: 14),
                  filled: true,
                  fillColor: const Color(0xFFF1F3F4),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _sendMessage,
              child: const Padding(
                padding: EdgeInsets.only(bottom: 2), // Alinhamento fino com o TextField
                child: CircleAvatar(
                  backgroundColor: Color(0xFF1A73E8),
                  radius: 22,
                  child: Icon(Icons.send_rounded, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
