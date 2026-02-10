import '../models/usuario_model.dart';
import '../services/api_service.dart';

class UsuariosRepository {
  final client = ApiService.client;

  Future<List<UsuarioModel>> obtenerUsuarios() async {
    final response = await client.from('usuarios').select();
    return (response as List).map((e) => UsuarioModel.fromMap(e)).toList();
  }

  /// Obtener usuarios SOLO clientes (excluye superadmin y admin)
  /// Usar para listas de participantes en préstamos, tandas, avales, etc.
  Future<List<UsuarioModel>> obtenerUsuariosClientes() async {
    // Primero obtenemos los IDs de usuarios con roles admin/superadmin
    final rolesAdmin = await client
        .from('roles')
        .select('id')
        .inFilter('nombre', ['superadmin', 'admin']);
    
    final rolesIds = (rolesAdmin as List).map((r) => r['id'] as String).toList();
    
    if (rolesIds.isEmpty) {
      // Si no hay roles admin definidos, devolver todos
      final response = await client.from('usuarios').select();
      return (response as List).map((e) => UsuarioModel.fromMap(e)).toList();
    }

    // Obtener usuarios que tienen roles admin/superadmin
    final usuariosAdmin = await client
        .from('usuarios_roles')
        .select('usuario_id')
        .inFilter('rol_id', rolesIds);
    
    final usuariosExcluir = (usuariosAdmin as List).map((u) => u['usuario_id'] as String).toSet();

    // Obtener todos los usuarios
    final response = await client.from('usuarios').select();
    
    // Filtrar excluyendo los admins
    return (response as List)
        .where((e) => !usuariosExcluir.contains(e['id']))
        .map((e) => UsuarioModel.fromMap(e))
        .toList();
  }

  Future<UsuarioModel?> obtenerUsuarioPorId(String id) async {
    final response = await client.from('usuarios').select().eq('id', id).maybeSingle();
    if (response == null) return null;
    return UsuarioModel.fromMap(response);
  }

  Future<bool> crearUsuario(UsuarioModel usuario) async {
    final response = await client.from('usuarios').insert(usuario.toMap());
    return response != null;
  }

  Future<bool> actualizarUsuario(UsuarioModel usuario) async {
    if (usuario.id == null) return false;
    final response = await client.from('usuarios').update(usuario.toMap()).eq('id', usuario.id!);
    return response != null;
  }

  Future<bool> eliminarUsuario(String id) async {
    final response = await client.from('usuarios').delete().eq('id', id);
    return response != null;
  }
}
