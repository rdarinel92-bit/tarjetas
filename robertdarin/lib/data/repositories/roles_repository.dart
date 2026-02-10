import '../models/rol_model.dart';
import '../services/api_service.dart';

class RolesRepository {
  final client = ApiService.client;

  Future<List<RolModel>> obtenerRoles() async {
    final response = await client.from('roles').select();
    return (response as List).map((e) => RolModel.fromMap(e)).toList();
  }

  Future<RolModel?> obtenerRolPorId(String id) async {
    final response = await client.from('roles').select().eq('id', id).maybeSingle();
    if (response == null) return null;
    return RolModel.fromMap(response);
  }

  Future<bool> crearRol(RolModel rol) async {
    final response = await client.from('roles').insert(rol.toMap());
    return response != null;
  }

  Future<bool> actualizarRol(RolModel rol) async {
    final response = await client.from('roles').update(rol.toMap()).eq('id', rol.id);
    return response != null;
  }

  Future<bool> eliminarRol(String id) async {
    final response = await client.from('roles').delete().eq('id', id);
    return response != null;
  }
}
