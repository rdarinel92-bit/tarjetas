import '../models/tanda_participante_model.dart';
import '../services/api_service.dart';

class TandaParticipantesRepository {
  final client = ApiService.client;

  /// Obtener todos los participantes de una tanda (con nombre de cliente)
  Future<List<TandaParticipanteModel>> obtenerParticipantesPorTanda(String tandaId) async {
    try {
      final response = await client
          .from('tanda_participantes')
          .select('*, clientes(nombre)')
          .eq('tanda_id', tandaId)
          .order('numero_turno');
      return (response as List).map((e) => TandaParticipanteModel.fromMap(e)).toList();
    } catch (e) {
      print('Error al obtener participantes: $e');
      return [];
    }
  }

  /// Agregar participante a una tanda
  Future<bool> agregarParticipante(TandaParticipanteModel participante) async {
    try {
      await client.from('tanda_participantes').insert(participante.toMapForInsert());
      return true;
    } catch (e) {
      print('Error al agregar participante: $e');
      return false;
    }
  }

  /// Agregar múltiples participantes (para migración)
  Future<bool> agregarParticipantesEnLote(List<TandaParticipanteModel> participantes) async {
    try {
      final data = participantes.map((p) => p.toMapForInsert()).toList();
      await client.from('tanda_participantes').insert(data);
      return true;
    } catch (e) {
      print('Error al agregar participantes en lote: $e');
      return false;
    }
  }

  /// Actualizar estado de pago de un participante
  Future<bool> marcarPagoCuota(String participanteId, bool pagado) async {
    try {
      await client
          .from('tanda_participantes')
          .update({'ha_pagado_cuota_actual': pagado})
          .eq('id', participanteId);
      return true;
    } catch (e) {
      print('Error al marcar pago: $e');
      return false;
    }
  }

  /// Marcar que un participante recibió la bolsa
  Future<bool> marcarBolsaEntregada(String participanteId) async {
    try {
      await client.from('tanda_participantes').update({
        'ha_recibido_bolsa': true,
        'fecha_recepcion_bolsa': DateTime.now().toIso8601String(),
      }).eq('id', participanteId);
      return true;
    } catch (e) {
      print('Error al marcar bolsa entregada: $e');
      return false;
    }
  }

  /// Reiniciar pagos de cuota para nuevo turno
  Future<bool> reiniciarPagosCuota(String tandaId) async {
    try {
      await client
          .from('tanda_participantes')
          .update({'ha_pagado_cuota_actual': false})
          .eq('tanda_id', tandaId);
      return true;
    } catch (e) {
      print('Error al reiniciar pagos: $e');
      return false;
    }
  }

  /// Eliminar participante de una tanda
  Future<bool> eliminarParticipante(String participanteId) async {
    try {
      await client.from('tanda_participantes').delete().eq('id', participanteId);
      return true;
    } catch (e) {
      print('Error al eliminar participante: $e');
      return false;
    }
  }

  /// Verificar si un cliente ya está en la tanda
  Future<bool> clienteYaEnTanda(String tandaId, String clienteId) async {
    try {
      final response = await client
          .from('tanda_participantes')
          .select('id')
          .eq('tanda_id', tandaId)
          .eq('cliente_id', clienteId)
          .maybeSingle();
      return response != null;
    } catch (e) {
      return false;
    }
  }

  /// Obtener el siguiente número de turno disponible
  Future<int> obtenerSiguienteTurno(String tandaId) async {
    try {
      final response = await client
          .from('tanda_participantes')
          .select('numero_turno')
          .eq('tanda_id', tandaId)
          .order('numero_turno', ascending: false)
          .limit(1)
          .maybeSingle();
      if (response == null) return 1;
      return (response['numero_turno'] as int) + 1;
    } catch (e) {
      return 1;
    }
  }
}
