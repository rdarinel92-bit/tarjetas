import 'package:flutter/material.dart';
// ignore: unused_import
import 'package:intl/intl.dart';
import '../core/supabase_client.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// SERVICIO DE COLABORADORES
// Funciones para gestión de colaboradores y permisos
// Robert Darin Platform v10.16
// ═══════════════════════════════════════════════════════════════════════════════

class ColaboradoresService {
  static final _client = AppSupabase.client;

  // ══════════════════════════════════════════════════════════════════════════
  // OBTENER COLABORADOR ACTUAL
  // ══════════════════════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>?> obtenerColaboradorActual() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return null;

      final res = await _client
          .from('v_colaboradores_completos')
          .select()
          .eq('auth_uid', user.id)
          .maybeSingle();

      return res;
    } catch (e) {
      debugPrint('Error al obtener colaborador actual: $e');
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // VERIFICAR SI ES COLABORADOR
  // ══════════════════════════════════════════════════════════════════════════
  static Future<bool> esColaborador() async {
    final colab = await obtenerColaboradorActual();
    return colab != null && colab['estado'] == 'activo';
  }

  // ══════════════════════════════════════════════════════════════════════════
  // OBTENER TIPO DE COLABORADOR
  // ══════════════════════════════════════════════════════════════════════════
  static Future<String?> obtenerTipoColaborador() async {
    final colab = await obtenerColaboradorActual();
    return colab?['tipo_codigo'] as String?;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // VERIFICAR PERMISO EN MÓDULO
  // ══════════════════════════════════════════════════════════════════════════
  static Future<Map<String, bool>> verificarPermisoModulo(String modulo) async {
    try {
      final colab = await obtenerColaboradorActual();
      if (colab == null) {
        return {'ver': true, 'crear': true, 'editar': true, 'eliminar': true, 'exportar': true};
      }

      final colaboradorId = colab['id'];

      // Buscar permiso específico
      final permiso = await _client
          .from('colaborador_permisos_modulo')
          .select()
          .eq('colaborador_id', colaboradorId)
          .eq('modulo', modulo)
          .maybeSingle();

      if (permiso != null) {
        return {
          'ver': permiso['puede_ver'] ?? false,
          'crear': permiso['puede_crear'] ?? false,
          'editar': permiso['puede_editar'] ?? false,
          'eliminar': permiso['puede_eliminar'] ?? false,
          'exportar': permiso['puede_exportar'] ?? false,
        };
      }

      // Si no hay permiso específico, usar permisos del tipo
      final tipoCodigo = colab['tipo_codigo'] as String?;
      return _permisosDefaultPorTipo(tipoCodigo, modulo);
    } catch (e) {
      debugPrint('Error al verificar permiso: $e');
      return {'ver': false, 'crear': false, 'editar': false, 'eliminar': false, 'exportar': false};
    }
  }

  static Map<String, bool> _permisosDefaultPorTipo(String? tipoCodigo, String modulo) {
    switch (tipoCodigo) {
      case 'co_superadmin':
        return {'ver': true, 'crear': true, 'editar': true, 'eliminar': true, 'exportar': true};
      
      case 'socio_operativo':
        return {'ver': true, 'crear': true, 'editar': true, 'eliminar': false, 'exportar': true};
      
      case 'inversionista':
        if (['dashboard', 'reportes'].contains(modulo)) {
          return {'ver': true, 'crear': false, 'editar': false, 'eliminar': false, 'exportar': true};
        }
        return {'ver': false, 'crear': false, 'editar': false, 'eliminar': false, 'exportar': false};
      
      case 'contador':
        if (['facturacion', 'reportes', 'pagos'].contains(modulo)) {
          return {'ver': true, 'crear': true, 'editar': true, 'eliminar': false, 'exportar': true};
        }
        return {'ver': true, 'crear': false, 'editar': false, 'eliminar': false, 'exportar': false};
      
      case 'facturador':
        if (modulo == 'facturacion') {
          return {'ver': true, 'crear': true, 'editar': true, 'eliminar': false, 'exportar': true};
        }
        return {'ver': false, 'crear': false, 'editar': false, 'eliminar': false, 'exportar': false};
      
      case 'asesor':
        return {'ver': true, 'crear': false, 'editar': false, 'eliminar': false, 'exportar': true};
      
      default:
        return {'ver': false, 'crear': false, 'editar': false, 'eliminar': false, 'exportar': false};
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PUEDE FACTURAR
  // ══════════════════════════════════════════════════════════════════════════
  static Future<bool> puedeFacturar() async {
    try {
      final colab = await obtenerColaboradorActual();
      if (colab == null) return true; // Usuario normal tiene acceso

      final tipoCodigo = colab['tipo_codigo'] as String?;
      
      // Tipos que pueden facturar
      if (['co_superadmin', 'socio_operativo', 'contador', 'facturador'].contains(tipoCodigo)) {
        return true;
      }

      // Verificar permiso específico de facturación
      final permiso = await verificarPermisoModulo('facturacion');
      return permiso['crear'] ?? false;
    } catch (e) {
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // REGISTRAR ACTIVIDAD
  // ══════════════════════════════════════════════════════════════════════════
  static Future<void> registrarActividad({
    required String tipoAccion,
    required String modulo,
    String? descripcion,
    Map<String, dynamic>? detalles,
    String? entidadId,
  }) async {
    try {
      final colab = await obtenerColaboradorActual();
      if (colab == null) return;

      await _client.from('colaborador_actividad').insert({
        'colaborador_id': colab['id'],
        'tipo_accion': tipoAccion,
        'modulo': modulo,
        'descripcion': descripcion,
        'detalles': detalles ?? {},
        'entidad_id': entidadId,
        'ip_address': null, // Se puede obtener si es necesario
      });
    } catch (e) {
      debugPrint('Error al registrar actividad: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // INVITAR COLABORADOR
  // ══════════════════════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>> invitarColaborador({
    required String email,
    required String nombre,
    required String tipoId,
    String? negocioId,
    double? porcentajeParticipacion,
  }) async {
    try {
      // Verificar si el email ya está registrado
      final existente = await _client
          .from('colaboradores')
          .select('id')
          .eq('email', email)
          .maybeSingle();

      if (existente != null) {
        return {'success': false, 'error': 'Este email ya está registrado como colaborador'};
      }

      // Generar token de invitación
      final token = DateTime.now().millisecondsSinceEpoch.toRadixString(36) +
          email.hashCode.toRadixString(36);

      // Crear invitación
      final invitacion = await _client
          .from('colaborador_invitaciones')
          .insert({
            'email': email,
            'nombre': nombre,
            'tipo_id': tipoId,
            'negocio_id': negocioId,
            'porcentaje_participacion': porcentajeParticipacion,
            'token': token,
            'expira_en': DateTime.now().add(const Duration(days: 7)).toIso8601String(),
            'invitado_por': _client.auth.currentUser?.id,
          })
          .select()
          .single();

      return {
        'success': true,
        'invitacion': invitacion,
        'token': token,
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ACEPTAR INVITACIÓN
  // ══════════════════════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>> aceptarInvitacion(String token) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        return {'success': false, 'error': 'Debes iniciar sesión para aceptar la invitación'};
      }

      // Buscar invitación
      final invitacion = await _client
          .from('colaborador_invitaciones')
          .select('*, colaborador_tipos(*)')
          .eq('token', token)
          .eq('estado', 'pendiente')
          .maybeSingle();

      if (invitacion == null) {
        return {'success': false, 'error': 'Invitación no válida o expirada'};
      }

      // Verificar expiración
      final expira = DateTime.parse(invitacion['expira_en']);
      if (DateTime.now().isAfter(expira)) {
        await _client
            .from('colaborador_invitaciones')
            .update({'estado': 'expirada'})
            .eq('id', invitacion['id']);
        return {'success': false, 'error': 'La invitación ha expirado'};
      }

      // Crear colaborador
      final colaborador = await _client
          .from('colaboradores')
          .insert({
            'auth_uid': user.id,
            'tipo_id': invitacion['tipo_id'],
            'negocio_id': invitacion['negocio_id'],
            'nombre': invitacion['nombre'],
            'email': user.email,
            'telefono': user.phone,
            'porcentaje_participacion': invitacion['porcentaje_participacion'],
            'estado': 'activo',
          })
          .select()
          .single();

      // Marcar invitación como aceptada
      await _client
          .from('colaborador_invitaciones')
          .update({
            'estado': 'aceptada',
            'aceptada_en': DateTime.now().toIso8601String(),
          })
          .eq('id', invitacion['id']);

      return {
        'success': true,
        'colaborador': colaborador,
        'tipo': invitacion['colaborador_tipos'],
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // LISTAR COLABORADORES
  // ══════════════════════════════════════════════════════════════════════════
  static Future<List<Map<String, dynamic>>> listarColaboradores({
    String? negocioId,
    String? tipoId,
    String? estado,
  }) async {
    try {
      var query = _client.from('v_colaboradores_completos').select();

      if (negocioId != null) {
        query = query.eq('negocio_id', negocioId);
      }
      if (tipoId != null) {
        query = query.eq('tipo_id', tipoId);
      }
      if (estado != null) {
        query = query.eq('estado', estado);
      }

      final res = await query.order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('Error al listar colaboradores: $e');
      return [];
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // OBTENER TIPOS DE COLABORADOR
  // ══════════════════════════════════════════════════════════════════════════
  static Future<List<Map<String, dynamic>>> obtenerTipos() async {
    try {
      final res = await _client
          .from('colaborador_tipos')
          .select()
          .eq('activo', true)
          .order('orden');
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('Error al obtener tipos: $e');
      return [];
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CAMBIAR ESTADO DE COLABORADOR
  // ══════════════════════════════════════════════════════════════════════════
  static Future<bool> cambiarEstado(String colaboradorId, String nuevoEstado) async {
    try {
      await _client
          .from('colaboradores')
          .update({'estado': nuevoEstado})
          .eq('id', colaboradorId);
      return true;
    } catch (e) {
      debugPrint('Error al cambiar estado: $e');
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // REGISTRAR INVERSIÓN
  // ══════════════════════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>> registrarInversion({
    required String colaboradorId,
    required String tipo, // aportacion, retiro
    required double monto,
    String? concepto,
    String? comprobanteUrl,
  }) async {
    try {
      final inversion = await _client
          .from('colaborador_inversiones')
          .insert({
            'colaborador_id': colaboradorId,
            'tipo': tipo,
            'monto': monto,
            'concepto': concepto,
            'comprobante_url': comprobanteUrl,
            'fecha': DateTime.now().toIso8601String(),
            'estado': 'confirmado',
            'registrado_por': _client.auth.currentUser?.id,
          })
          .select()
          .single();

      // Actualizar total invertido del colaborador
      await _actualizarTotalInvertido(colaboradorId);

      return {'success': true, 'inversion': inversion};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<void> _actualizarTotalInvertido(String colaboradorId) async {
    try {
      final inversiones = await _client
          .from('colaborador_inversiones')
          .select('tipo, monto')
          .eq('colaborador_id', colaboradorId)
          .eq('estado', 'confirmado');

      double total = 0;
      for (var inv in inversiones) {
        if (inv['tipo'] == 'aportacion') {
          total += (inv['monto'] as num).toDouble();
        } else if (inv['tipo'] == 'retiro') {
          total -= (inv['monto'] as num).toDouble();
        }
      }

      await _client
          .from('colaboradores')
          .update({'total_invertido': total})
          .eq('id', colaboradorId);
    } catch (e) {
      debugPrint('Error al actualizar total invertido: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // REGISTRAR RENDIMIENTO
  // ══════════════════════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>> registrarRendimiento({
    required String colaboradorId,
    required DateTime periodoInicio,
    required DateTime periodoFin,
    required double montoBase,
    required double tasaAplicada,
    required double montoRendimiento,
  }) async {
    try {
      final rendimiento = await _client
          .from('colaborador_rendimientos')
          .insert({
            'colaborador_id': colaboradorId,
            'periodo_inicio': periodoInicio.toIso8601String(),
            'periodo_fin': periodoFin.toIso8601String(),
            'monto_base': montoBase,
            'tasa_aplicada': tasaAplicada,
            'monto_rendimiento': montoRendimiento,
            'estado': 'pendiente',
          })
          .select()
          .single();

      return {'success': true, 'rendimiento': rendimiento};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PAGAR RENDIMIENTO
  // ══════════════════════════════════════════════════════════════════════════
  static Future<bool> pagarRendimiento(String rendimientoId) async {
    try {
      await _client
          .from('colaborador_rendimientos')
          .update({
            'estado': 'pagado',
            'fecha_pago': DateTime.now().toIso8601String(),
          })
          .eq('id', rendimientoId);
      return true;
    } catch (e) {
      debugPrint('Error al pagar rendimiento: $e');
      return false;
    }
  }
}
