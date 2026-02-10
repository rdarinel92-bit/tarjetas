import '../../../../data/models/aval_model.dart';
import '../../../../data/repositories/avales_repository.dart';

class AvalesController {
  final AvalesRepository repository;

  AvalesController({required this.repository});

  Future<List<AvalModel>> obtenerAvales() async {
    return await repository.obtenerAvales();
  }

  Future<AvalModel?> obtenerAval(String id) async {
    return await repository.obtenerAvalPorId(id);
  }

  /// Crea un aval SIN cuenta de usuario
  Future<bool> crearAval(AvalModel aval) async {
    return await repository.crearAval(aval);
  }

  /// Crea un aval CON cuenta de usuario para acceso a la app
  Future<bool> crearAvalConCuenta(AvalModel aval, String password) async {
    return await repository.crearAvalConCuenta(aval, password);
  }

  Future<bool> actualizarAval(AvalModel aval) async {
    return await repository.actualizarAval(aval);
  }

  Future<bool> eliminarAval(String id) async {
    return await repository.eliminarAval(id);
  }

  /// V10.55: Crea un aval y lo vincula con un préstamo
  Future<String?> crearAvalYVincular({
    required AvalModel aval,
    required String prestamoId,
    int orden = 1,
    String? password,
  }) async {
    return await repository.crearAvalYVincular(
      aval: aval,
      prestamoId: prestamoId,
      orden: orden,
      password: password,
    );
  }

  /// V10.55: Obtiene el límite máximo de avales por préstamo
  Future<int> obtenerMaxAvalesPrestamo() async {
    return await repository.obtenerMaxAvalesPrestamo();
  }
}
