import '../models/aval_model.dart';
import '../services/api_service.dart';
import '../../services/auth_creacion_service.dart';

class AvalesRepository {
  final client = ApiService.client;

  Future<List<AvalModel>> obtenerAvales() async {
    final response = await client.from('avales').select();
    return (response as List).map((e) => AvalModel.fromMap(e)).toList();
  }

  Future<AvalModel?> obtenerAvalPorId(String id) async {
    final response = await client.from('avales').select().eq('id', id).maybeSingle();
    if (response == null) return null;
    return AvalModel.fromMap(response);
  }

  /// Crea un aval SIN cuenta de usuario (método original)
  Future<bool> crearAval(AvalModel aval) async {
    try {
      await client.from('avales').insert(aval.toMapForInsert());
      return true;
    } catch (e) {
      print('Error al crear aval: $e');
      return false;
    }
  }

  /// Crea un aval CON cuenta de usuario para que pueda acceder a la app
  /// V10.55: Refactorizado para usar AuthCreacionService
  Future<bool> crearAvalConCuenta(AvalModel aval, String password) async {
    try {
      // 1. Usar AuthCreacionService para crear cuenta con rol correcto
      final authUserId = await AuthCreacionService.crearCuentaAuth(
        email: aval.email,
        password: password,
        nombreCompleto: aval.nombre,
        tipoUsuario: 'aval',
      );

      if (authUserId == null) {
        print('Error: No se pudo crear el usuario en Auth');
        return false;
      }

      // 2. Crear registro en tabla avales vinculado al usuario
      await client.from('avales').insert({
        'nombre': aval.nombre,
        'email': aval.email,
        'telefono': aval.telefono,
        'direccion': aval.direccion,
        'relacion': aval.relacion,
        'cliente_id': aval.clienteId,
        'usuario_id': authUserId,
        'identificacion': aval.identificacion,
      });

      print('✅ Aval creado con cuenta de usuario: ${aval.email}');
      return true;
    } catch (e) {
      print('Error al crear aval con cuenta: $e');
      return false;
    }
  }

  Future<bool> actualizarAval(AvalModel aval) async {
    final response = await client.from('avales').update(aval.toMap()).eq('id', aval.id);
    return response != null;
  }

  Future<bool> eliminarAval(String id) async {
    final response = await client.from('avales').delete().eq('id', id);
    return response != null;
  }

  /// V10.55: Vincula un aval con un préstamo en la tabla prestamos_avales
  /// Retorna el ID del registro creado si tiene éxito
  Future<String?> vincularAvalConPrestamo({
    required String prestamoId,
    required String avalId,
    int orden = 1,
    String tipo = 'garante',
    double porcentajeResponsabilidad = 100.0,
  }) async {
    try {
      final response = await client.from('prestamos_avales').insert({
        'prestamo_id': prestamoId,
        'aval_id': avalId,
        'orden': orden,
        'tipo': tipo,
        'porcentaje_responsabilidad': porcentajeResponsabilidad,
        'estado': 'pendiente',
      }).select().single();
      return response['id'];
    } catch (e) {
      print('Error al vincular aval con préstamo: $e');
      return null;
    }
  }

  /// V10.55: Cuenta avales activos para un préstamo específico
  Future<int> contarAvalesPrestamo(String prestamoId) async {
    try {
      final response = await client
          .from('prestamos_avales')
          .select('id')
          .eq('prestamo_id', prestamoId);
      return (response as List).length;
    } catch (e) {
      print('Error contando avales del préstamo: $e');
      return 0;
    }
  }

  /// V10.55: Obtiene el límite de avales configurado
  Future<int> obtenerMaxAvalesPrestamo() async {
    try {
      final response = await client
          .from('configuracion_global')
          .select('max_avales_prestamo')
          .limit(1)
          .maybeSingle();
      return response?['max_avales_prestamo'] ?? 3;
    } catch (e) {
      print('Error obteniendo max_avales_prestamo: $e');
      return 3; // Default
    }
  }

  /// V10.55: Crea un aval y lo vincula inmediatamente con un préstamo
  /// Retorna el ID del aval creado o null si falla
  Future<String?> crearAvalYVincular({
    required AvalModel aval,
    required String prestamoId,
    int orden = 1,
    String? password,
  }) async {
    try {
      String? avalId;

      // Crear aval con o sin cuenta
      if (password != null && password.isNotEmpty && aval.email.isNotEmpty) {
        final authUserId = await AuthCreacionService.crearCuentaAuth(
          email: aval.email,
          password: password,
          nombreCompleto: aval.nombre,
          tipoUsuario: 'aval',
        );
        if (authUserId == null) return null;

        final response = await client.from('avales').insert({
          'nombre': aval.nombre,
          'email': aval.email,
          'telefono': aval.telefono,
          'direccion': aval.direccion,
          'relacion': aval.relacion,
          'cliente_id': aval.clienteId,
          'usuario_id': authUserId,
          'identificacion': aval.identificacion,
        }).select().single();
        avalId = response['id'];
      } else {
        final response = await client.from('avales').insert(aval.toMapForInsert()).select().single();
        avalId = response['id'];
      }

      // Vincular con préstamo
      if (avalId != null) {
        await vincularAvalConPrestamo(
          prestamoId: prestamoId,
          avalId: avalId,
          orden: orden,
        );
      }

      return avalId;
    } catch (e) {
      print('Error en crearAvalYVincular: $e');
      return null;
    }
  }
}
