import '../../../../data/models/prestamo_model.dart';
import '../../../../data/repositories/prestamos_repository.dart';

class PrestamosController {
  final PrestamosRepository repository;

  PrestamosController({required this.repository});

  Future<List<PrestamoModel>> obtenerPrestamos() async {
    return await repository.obtenerPrestamos();
  }

  Future<PrestamoModel?> obtenerPrestamo(String id) async {
    return await repository.obtenerPrestamoPorId(id);
  }

  Future<bool> crearPrestamo(PrestamoModel prestamo) async {
    return await repository.crearPrestamo(prestamo);
  }

  /// Crear préstamo y retornar el ID generado
  Future<String?> crearPrestamoConId(PrestamoModel prestamo) async {
    return await repository.crearPrestamoConId(prestamo);
  }

  Future<bool> actualizarPrestamo(PrestamoModel prestamo) async {
    return await repository.actualizarPrestamo(prestamo);
  }

  Future<bool> eliminarPrestamo(String id) async {
    return await repository.eliminarPrestamo(id);
  }
}
