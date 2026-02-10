import '../models/comprobante_prestamo_model.dart';
import '../services/api_service.dart';

class ComprobantesPrestamoRepository {
  final client = ApiService.client;

  Future<List<ComprobantePrestamoModel>> obtenerComprobantesPorPrestamo(String prestamoId) async {
    final response = await client
        .from('comprobantes_prestamo')
        .select()
        .eq('prestamo_id', prestamoId)
        .order('created_at', ascending: false);
    return (response as List).map((e) => ComprobantePrestamoModel.fromMap(e)).toList();
  }

  Future<bool> crearComprobante(ComprobantePrestamoModel comprobante) async {
    final response = await client.from('comprobantes_prestamo').insert(comprobante.toMap());
    return response != null;
  }
}
