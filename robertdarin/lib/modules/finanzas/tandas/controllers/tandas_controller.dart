import '../../../../data/models/tanda_model.dart';
import '../../../../data/repositories/tandas_repository.dart';

class TandasController {
  final TandasRepository repository;

  TandasController({required this.repository});

  Future<List<TandaModel>> obtenerTandas() async {
    return await repository.obtenerTandas();
  }

  Future<TandaModel?> obtenerTanda(String id) async {
    return await repository.obtenerTandaPorId(id);
  }

  Future<bool> crearTanda(TandaModel tanda) async {
    return await repository.crearTanda(tanda);
  }

  Future<String?> crearTandaConId(TandaModel tanda) async {
    return await repository.crearTandaConId(tanda);
  }

  Future<bool> actualizarTanda(TandaModel tanda) async {
    return await repository.actualizarTanda(tanda);
  }

  Future<bool> eliminarTanda(String id) async {
    return await repository.eliminarTanda(id);
  }
}
