
import '../models/tanda_model.dart';
import '../services/api_service.dart';

class TandasRepository {
  final client = ApiService.client;

  Future<List<TandaModel>> obtenerTandas() async {
    try {
      final response = await client.from('tandas').select().order('fecha_inicio', ascending: false);
      return (response as List).map((e) => TandaModel.fromMap(e)).toList();
    } catch (e) {
      print('Error al obtener tandas: $e');
      return [];
    }
  }

  Future<List<TandaModel>> obtenerTandasActivas() async {
    try {
      final response = await client
          .from('tandas')
          .select()
          .eq('estado', 'activa')
          .order('fecha_inicio', ascending: false);
      return (response as List).map((e) => TandaModel.fromMap(e)).toList();
    } catch (e) {
      print('Error al obtener tandas activas: $e');
      return [];
    }
  }

  Future<TandaModel?> obtenerTandaPorId(String id) async {
    try {
      final response = await client.from('tandas').select().eq('id', id).maybeSingle();
      if (response == null) return null;
      return TandaModel.fromMap(response);
    } catch (e) {
      print('Error al obtener tanda: $e');
      return null;
    }
  }

  Future<bool> crearTanda(TandaModel tanda) async {
    try {
      await client.from('tandas').insert(tanda.toMapForInsert());
      return true;
    } catch (e) {
      print('Error al crear tanda: $e');
      return false;
    }
  }

  /// Crear tanda y retornar el ID generado
  Future<String?> crearTandaConId(TandaModel tanda) async {
    try {
      final response = await client
          .from('tandas')
          .insert(tanda.toMapForInsert())
          .select('id')
          .single();
      return response['id'];
    } catch (e) {
      print('Error al crear tanda: $e');
      return null;
    }
  }

  Future<bool> actualizarTanda(TandaModel tanda) async {
    try {
      await client.from('tandas').update(tanda.toMap()).eq('id', tanda.id);
      return true;
    } catch (e) {
      print('Error al actualizar tanda: $e');
      return false;
    }
  }

  /// Avanzar al siguiente turno
  Future<bool> avanzarTurno(String tandaId, int nuevoTurno) async {
    try {
      await client.from('tandas').update({'turno': nuevoTurno}).eq('id', tandaId);
      return true;
    } catch (e) {
      print('Error al avanzar turno: $e');
      return false;
    }
  }

  /// Finalizar tanda
  Future<bool> finalizarTanda(String tandaId) async {
    try {
      await client.from('tandas').update({
        'estado': 'completada',
        'fecha_fin': DateTime.now().toIso8601String(),
      }).eq('id', tandaId);
      return true;
    } catch (e) {
      print('Error al finalizar tanda: $e');
      return false;
    }
  }

  Future<bool> eliminarTanda(String id) async {
    try {
      await client.from('tandas').delete().eq('id', id);
      return true;
    } catch (e) {
      print('Error al eliminar tanda: $e');
      return false;
    }
  }
}

