import 'package:flutter/foundation.dart';
import '../../data/repositories/kpi_repository.dart';

class KpiViewModel extends ChangeNotifier {
  final KpiRepository repo;

  int totalClientes = 0;
  int prestamosActivos = 0;
  int tandasActivas = 0;
  int empleados = 0;
  int pagosMes = 0;
  bool cargando = false;

  KpiViewModel({required this.repo});

  Future<void> cargarKpis() async {
    cargando = true;
    notifyListeners();

    totalClientes = await repo.contarClientes();
    prestamosActivos = await repo.contarPrestamosActivos();
    tandasActivas = await repo.contarTandasActivas();
    empleados = await repo.contarEmpleados();
    pagosMes = await repo.contarPagosMesActual();

    cargando = false;
    notifyListeners();
  }
}
