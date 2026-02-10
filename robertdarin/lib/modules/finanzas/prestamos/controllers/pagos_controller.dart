import '../../../../data/models/pago_model.dart';
import '../../../../data/repositories/pagos_repository.dart';

class PagosController {
  final PagosRepository repository;

  PagosController({required this.repository});

  Future<List<PagoModel>> obtenerPagosPorPrestamo(String prestamoId) async {
    return await repository.obtenerPagosPorPrestamo(prestamoId);
  }

  Future<bool> crearPago(PagoModel pago) async {
    return await repository.crearPago(pago);
  }
}
