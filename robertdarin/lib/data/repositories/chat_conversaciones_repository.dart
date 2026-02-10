import '../models/chat_conversacion_model.dart';
import '../services/api_service.dart';

class ChatConversacionesRepository {
  final client = ApiService.client;

  Future<List<ChatConversacionModel>> obtenerConversacionesPorUsuario(String usuarioId) async {
    final response = await client
        .from('chat_conversaciones')
        .select('*,chat_participantes!inner(usuario_id)')
        .eq('chat_participantes.usuario_id', usuarioId)
        .order('created_at', ascending: false);
    return (response as List).map((e) => ChatConversacionModel.fromMap(e)).toList();
  }

  Future<ChatConversacionModel?> obtenerConversacionPorId(String id) async {
    final response = await client.from('chat_conversaciones').select().eq('id', id).maybeSingle();
    if (response == null) return null;
    return ChatConversacionModel.fromMap(response);
  }

  Future<ChatConversacionModel?> crearConversacion(ChatConversacionModel conversacion) async {
    final response = await client.from('chat_conversaciones').insert(conversacion.toMap()).select().maybeSingle();
    if (response == null) return null;
    return ChatConversacionModel.fromMap(response);
  }

  Future<bool> actualizarEstadoConversacion(String id, String nuevoEstado) async {
    final response = await client.from('chat_conversaciones').update({'estado': nuevoEstado}).eq('id', id);
    return response != null;
  }
}
