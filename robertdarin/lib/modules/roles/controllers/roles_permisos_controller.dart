import '../../../data/models/rol_model.dart';
import '../../../data/models/permiso_model.dart';
import '../../../data/models/rol_permiso_model.dart';
import '../../../data/models/usuario_rol_model.dart';
import '../../../data/models/auditoria_acceso_model.dart';
import '../../../data/repositories/roles_repository.dart';
import '../../../data/repositories/permisos_repository.dart';
import '../../../data/repositories/roles_permisos_repository.dart';
import '../../../data/repositories/usuarios_roles_repository.dart';
import '../../../data/repositories/auditoria_accesos_repository.dart';

class RolesPermisosController {
  final RolesRepository rolesRepository;
  final PermisosRepository permisosRepository;
  final RolesPermisosRepository rolesPermisosRepository;
  final UsuariosRolesRepository usuariosRolesRepository;
  final AuditoriaAccesosRepository auditoriaAccesosRepository;

  RolesPermisosController({
    required this.rolesRepository,
    required this.permisosRepository,
    required this.rolesPermisosRepository,
    required this.usuariosRolesRepository,
    required this.auditoriaAccesosRepository,
  });

  Future<List<RolModel>> obtenerRoles() async {
    return await rolesRepository.obtenerRoles();
  }

  Future<List<PermisoModel>> obtenerPermisos() async {
    return await permisosRepository.obtenerPermisos();
  }

  Future<List<RolPermisoModel>> obtenerPermisosPorRol(String rolId) async {
    return await rolesPermisosRepository.obtenerPermisosPorRol(rolId);
  }

  Future<bool> asignarPermisoARol({
    required String rolId,
    required String permisoId,
  }) async {
    final rp = RolPermisoModel(
      id: '',
      rolId: rolId,
      permisoId: permisoId,
      createdAt: DateTime.now(),
    );
    return await rolesPermisosRepository.asignarPermiso(rp);
  }

  Future<bool> quitarPermisoDeRol(String rolPermisoId) async {
    return await rolesPermisosRepository.eliminarPermisoAsignado(rolPermisoId);
  }

  Future<UsuarioRolModel?> obtenerRolDeUsuario(String usuarioId) async {
    return await usuariosRolesRepository.obtenerRolDeUsuario(usuarioId);
  }

  Future<bool> asignarRolAUsuario({
    required String usuarioId,
    required String rolId,
  }) async {
    final ur = UsuarioRolModel(
      id: '',
      usuarioId: usuarioId,
      rolId: rolId,
    );
    return await usuariosRolesRepository.asignarRolAUsuario(ur);
  }

  Future<bool> cambiarRolDeUsuario({
    required String usuarioId,
    required String nuevoRolId,
  }) async {
    return await usuariosRolesRepository.cambiarRolDeUsuario(usuarioId, nuevoRolId);
  }

  Future<bool> usuarioTienePermiso({
    required String usuarioId,
    required String clavePermiso,
  }) async {
    final usuarioRol = await obtenerRolDeUsuario(usuarioId);
    if (usuarioRol == null) return false;
    final permisosRol = await obtenerPermisosPorRol(usuarioRol.rolId);
    for (final rp in permisosRol) {
      final permiso = await permisosRepository.obtenerPermisoPorId(rp.permisoId);
      if (permiso != null && permiso.clavePermiso == clavePermiso) {
        return true;
      }
    }
    return false;
  }

  Future<bool> registrarAuditoria({
    required String usuarioId,
    required String rolId,
    required String accion,
    required String entidad,
    required String entidadId,
    String? ip,
    double? latitud,
    double? longitud,
    String? dispositivo,
    required String hashContenido,
  }) async {
    final registro = AuditoriaAccesoModel(
      id: '',
      usuarioId: usuarioId,
      rolId: rolId,
      accion: accion,
      entidad: entidad,
      entidadId: entidadId,
      ip: ip,
      latitud: latitud,
      longitud: longitud,
      dispositivo: dispositivo,
      hashContenido: hashContenido,
      createdAt: DateTime.now(),
    );
    return await auditoriaAccesosRepository.registrarAcceso(registro);
  }
}
