import '../models/chat_participante_model.dart';
import '../services/api_service.dart';

class ChatParticipantesRepository {
  final client = ApiService.client;

  Future<List<ChatParticipanteModel>> obtenerParticipantesPorConversacion(String conversacionId) async {
    final response = await client
        .from('chat_participantes')
        .select()
        .eq('conversacion_id', conversacionId);
    return (response as List).map((e) => ChatParticipanteModel.fromMap(e)).toList();
  }

  Future<List<ChatParticipanteModel>> obtenerParticipacionesPorUsuario(String usuarioId) async {
    final response = await client
        .from('chat_participantes')
        .select()
        .eq('usuario_id', usuarioId);
    return (response as List).map((e) => ChatParticipanteModel.fromMap(e)).toList();
  }

  Future<bool> agregarParticipante(ChatParticipanteModel participante) async {
    final response = await client.from('chat_participantes').insert(participante.toMap());
    return response != null;
  }

  Future<bool> actualizarNotificaciones(String participanteId, bool activas) async {
    final response = await client
        .from('chat_participantes')
        .update({'silenciado': !activas})
        .eq('id', participanteId);
    return response != null;
  }
}
