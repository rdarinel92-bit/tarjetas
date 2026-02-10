import '../../../data/models/usuario_model.dart';
import '../../../data/repositories/usuarios_repository.dart';

class UsuariosController {
  final UsuariosRepository repository;

  UsuariosController({required this.repository});

  Future<List<UsuarioModel>> obtenerUsuarios() async {
    return await repository.obtenerUsuarios();
  }

  /// Obtener solo usuarios clientes (excluye superadmin y admin)
  /// Usar para listas de participantes en préstamos, tandas, avales, etc.
  Future<List<UsuarioModel>> obtenerUsuariosClientes() async {
    return await repository.obtenerUsuariosClientes();
  }

  Future<UsuarioModel?> obtenerUsuario(String id) async {
    return await repository.obtenerUsuarioPorId(id);
  }

  Future<bool> crearUsuario(UsuarioModel usuario) async {
    return await repository.crearUsuario(usuario);
  }

  Future<bool> actualizarUsuario(UsuarioModel usuario) async {
    return await repository.actualizarUsuario(usuario);
  }

  Future<bool> eliminarUsuario(String id) async {
    return await repository.eliminarUsuario(id);
  }
}
