import '../models/rol_permiso_model.dart';
import '../services/api_service.dart';

class RolesPermisosRepository {
  final client = ApiService.client;

  Future<List<RolPermisoModel>> obtenerPermisosPorRol(String rolId) async {
    final response = await client.from('roles_permisos').select().eq('rol_id', rolId);
    return (response as List).map((e) => RolPermisoModel.fromMap(e)).toList();
  }

  Future<bool> asignarPermiso(RolPermisoModel rp) async {
    final response = await client.from('roles_permisos').insert(rp.toMap());
    return response != null;
  }

  Future<bool> eliminarPermisoAsignado(String id) async {
    final response = await client.from('roles_permisos').delete().eq('id', id);
    return response != null;
  }
}
