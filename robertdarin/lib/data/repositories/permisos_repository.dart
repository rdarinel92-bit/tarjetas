import '../models/permiso_model.dart';
import '../services/api_service.dart';

class PermisosRepository {
  final client = ApiService.client;

  Future<List<PermisoModel>> obtenerPermisos() async {
    final response = await client.from('permisos').select();
    return (response as List).map((e) => PermisoModel.fromMap(e)).toList();
  }

  Future<PermisoModel?> obtenerPermisoPorId(String id) async {
    final response = await client.from('permisos').select().eq('id', id).maybeSingle();
    if (response == null) return null;
    return PermisoModel.fromMap(response);
  }

  Future<bool> crearPermiso(PermisoModel permiso) async {
    final response = await client.from('permisos').insert(permiso.toMap());
    return response != null;
  }

  Future<bool> actualizarPermiso(PermisoModel permiso) async {
    final response = await client.from('permisos').update(permiso.toMap()).eq('id', permiso.id);
    return response != null;
  }

  Future<bool> eliminarPermiso(String id) async {
    final response = await client.from('permisos').delete().eq('id', id);
    return response != null;
  }
}
