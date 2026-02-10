import '../models/chat_mensaje_model.dart';
import '../services/api_service.dart';

class ChatMensajesRepository {
  final client = ApiService.client;

  Future<List<ChatMensajeModel>> obtenerMensajesPorConversacion(String conversacionId) async {
    final response = await client
        .from('chat_mensajes')
        .select()
        .eq('conversacion_id', conversacionId)
        .order('created_at', ascending: true);
    return (response as List).map((e) => ChatMensajeModel.fromMap(e)).toList();
  }

  Future<ChatMensajeModel?> crearMensaje(ChatMensajeModel mensaje) async {
    final response = await client.from('chat_mensajes').insert(mensaje.toMap()).select().maybeSingle();
    if (response == null) return null;
    return ChatMensajeModel.fromMap(response);
  }
}
