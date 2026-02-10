import 'package:flutter/foundation.dart';
import '../../data/repositories/roles_repository.dart';
import '../../data/models/rol_model.dart';

class RolesViewModel extends ChangeNotifier {
  final RolesRepository repo;

  List<RolModel> roles = [];
  bool cargando = false;

  RolesViewModel({required this.repo});

  Future<void> cargarRoles() async {
    cargando = true;
    notifyListeners();
    roles = await repo.obtenerRoles();
    cargando = false;
    notifyListeners();
  }

  Future<void> crearRol(RolModel rol) async {
    await repo.crearRol(rol);
    await cargarRoles();
  }
}
