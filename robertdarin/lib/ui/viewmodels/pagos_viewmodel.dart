import 'package:flutter/foundation.dart';
import '../../data/repositories/pagos_repository.dart';
import '../../data/models/pago_model.dart';

class PagosViewModel extends ChangeNotifier {
  final PagosRepository repo;

  List<PagoModel> pagos = [];
  bool cargando = false;

  PagosViewModel({required this.repo});

  Future<void> cargarPagosPorPrestamo(String prestamoId) async {
    cargando = true;
    notifyListeners();
    pagos = await repo.obtenerPagosPorPrestamo(prestamoId);
    cargando = false;
    notifyListeners();
  }

  Future<void> registrarPago(PagoModel pago) async {
    await repo.crearPago(pago);
    await cargarPagosPorPrestamo(pago.prestamoId);
  }
}
