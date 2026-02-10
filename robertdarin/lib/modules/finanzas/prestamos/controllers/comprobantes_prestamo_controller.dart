import '../../../../data/models/comprobante_prestamo_model.dart';
import '../../../../data/repositories/comprobantes_prestamo_repository.dart';

class ComprobantesPrestamoController {
  final ComprobantesPrestamoRepository repository;

  ComprobantesPrestamoController({required this.repository});

  Future<List<ComprobantePrestamoModel>> obtenerComprobantesPorPrestamo(String prestamoId) async {
    return await repository.obtenerComprobantesPorPrestamo(prestamoId);
  }

  Future<bool> crearComprobante(ComprobantePrestamoModel comprobante) async {
    return await repository.crearComprobante(comprobante);
  }
}
