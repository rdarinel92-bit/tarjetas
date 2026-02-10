import 'package:supabase_flutter/supabase_flutter.dart';

class ChatRepository {
  final supabase = Supabase.instance.client;

  Future<List<Map>> obtenerChats(String userId) async {
    return await supabase
      .from('chats')
      .select()
      .or('usuario1.eq.$userId,usuario2.eq.$userId');
  }

  Future<List<Map>> obtenerMensajes(String chatId) async {
    return await supabase
      .from('mensajes')
      .select()
      .eq('chat_id', chatId)
      .order('fecha');
  }

  Future<void> enviarMensaje(String chatId, String emisor, String contenido) async {
    await supabase.from('mensajes').insert({
      'chat_id': chatId,
      'emisor': emisor,
      'contenido': contenido
    });
  }
}
