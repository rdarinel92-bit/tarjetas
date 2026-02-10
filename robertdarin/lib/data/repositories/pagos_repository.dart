import '../models/pago_model.dart';
import '../services/api_service.dart';

class PagosRepository {
  final client = ApiService.client;

  Future<List<PagoModel>> obtenerPagosPorPrestamo(String prestamoId) async {
    final response = await client
        .from('pagos')
        .select()
        .eq('prestamo_id', prestamoId)
        .order('fecha_pago', ascending: false);
    return (response as List).map((e) => PagoModel.fromMap(e)).toList();
  }

  Future<bool> crearPago(PagoModel pago) async {
    final response = await client.from('pagos').insert(pago.toMap());
    return response != null;
  }
}
