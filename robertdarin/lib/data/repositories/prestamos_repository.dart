
import '../models/prestamo_model.dart';
import '../services/api_service.dart';

class PrestamosRepository {
  final client = ApiService.client;

  Future<List<PrestamoModel>> obtenerPrestamos() async {
    final response = await client.from('prestamos').select();
    return (response as List).map((e) => PrestamoModel.fromMap(e)).toList();
  }

  Future<PrestamoModel?> obtenerPrestamoPorId(String id) async {
    final response = await client.from('prestamos').select().eq('id', id).maybeSingle();
    if (response == null) return null;
    return PrestamoModel.fromMap(response);
  }

  Future<bool> crearPrestamo(PrestamoModel prestamo) async {
    try {
      await client.from('prestamos').insert(prestamo.toMapForInsert());
      return true;
    } catch (e) {
      print('Error al crear préstamo: $e');
      return false;
    }
  }

  /// Crear préstamo y retornar el ID generado
  Future<String?> crearPrestamoConId(PrestamoModel prestamo) async {
    try {
      final response = await client
          .from('prestamos')
          .insert(prestamo.toMapForInsert())
          .select('id')
          .single();
      return response['id'];
    } catch (e) {
      print('Error al crear préstamo: $e');
      return null;
    }
  }

  Future<bool> actualizarPrestamo(PrestamoModel prestamo) async {
    final response = await client.from('prestamos').update(prestamo.toMap()).eq('id', prestamo.id);
    return response != null;
  }

  Future<bool> eliminarPrestamo(String id) async {
    final response = await client.from('prestamos').delete().eq('id', id);
    return response != null;
  }
}
