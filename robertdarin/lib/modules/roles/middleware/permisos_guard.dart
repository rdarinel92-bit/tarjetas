import '../controllers/roles_permisos_controller.dart';

class PermisosGuard {
  final RolesPermisosController controller;

  PermisosGuard({required this.controller});

  Future<bool> validarPermiso({
    required String usuarioId,
    required String permisoRequerido,
    required String accion,
    required String entidad,
    required String entidadId,
    String? ip,
    double? latitud,
    double? longitud,
    String? dispositivo,
  }) async {
    final usuarioRol = await controller.obtenerRolDeUsuario(usuarioId);
    if (usuarioRol == null) {
      await controller.registrarAuditoria(
        usuarioId: usuarioId,
        rolId: '',
        accion: 'acceso_denegado',
        entidad: entidad,
        entidadId: entidadId,
        ip: ip,
        latitud: latitud,
        longitud: longitud,
        dispositivo: dispositivo,
        hashContenido: permisoRequerido,
      );
      return false;
    }
    final permisosRol = await controller.obtenerPermisosPorRol(usuarioRol.rolId);
    bool autorizado = false;
    for (final rp in permisosRol) {
      final permiso = await controller.permisosRepository.obtenerPermisoPorId(rp.permisoId);
      if (permiso != null && permiso.clavePermiso == permisoRequerido) {
        autorizado = true;
        break;
      }
    }
    await controller.registrarAuditoria(
      usuarioId: usuarioId,
      rolId: usuarioRol.rolId,
      accion: autorizado ? 'acceso_autorizado' : 'acceso_denegado',
      entidad: entidad,
      entidadId: entidadId,
      ip: ip,
      latitud: latitud,
      longitud: longitud,
      dispositivo: dispositivo,
      hashContenido: permisoRequerido,
    );
    return autorizado;
  }
}
