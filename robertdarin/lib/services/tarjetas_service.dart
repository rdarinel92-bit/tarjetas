// ═══════════════════════════════════════════════════════════════════════════════
// SERVICIO DE TARJETAS VIRTUALES
// Robert Darin Platform v10.14 - V10.22 UNIFICADO
// Soporta: Pomelo, Rapyd, Stripe Issuing, Galileo
// ═══════════════════════════════════════════════════════════════════════════════

import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/supabase_client.dart';
import '../data/models/tarjetas_models.dart';

/// Servicio principal de tarjetas virtuales
class TarjetasService {
  
  // ═══════════════════════════════════════════════════════════════════════════════
  // CONFIGURACIÓN - V10.22 Unificado con configuracion_apis
  // ═══════════════════════════════════════════════════════════════════════════════
  
  /// Obtener configuración del proveedor de tarjetas
  /// V10.22: Ahora usa tabla configuracion_apis con servicio='tarjetas_digitales'
  Future<TarjetasConfigModel?> obtenerConfiguracion(String negocioId) async {
    try {
      final res = await AppSupabase.client
          .from('configuracion_apis')
          .select()
          .eq('servicio', 'tarjetas_digitales')
          .maybeSingle();
      
      if (res == null) return null;
      
      // V10.22: Mapear desde configuracion_apis a TarjetasConfigModel
      final config = res['configuracion'] as Map<String, dynamic>? ?? {};
      
      return TarjetasConfigModel(
        id: res['id'] ?? '',
        negocioId: res['negocio_id'] ?? negocioId,
        proveedor: config['proveedor'] ?? 'stripe',
        apiKey: res['api_key'],
        apiSecret: res['secret_key'],
        webhookSecret: res['webhook_secret'],
        apiBaseUrl: config['api_base_url'],
        webhookUrl: config['webhook_url'],
        accountId: config['account_id'],
        programId: config['program_id'],
        modoPruebas: res['modo_test'] == true,
        limiteDiarioDefault: (config['limite_diario_default'] ?? 10000).toDouble(),
        limiteMensualDefault: (config['limite_mensual_default'] ?? 50000).toDouble(),
        limiteTransaccionDefault: (config['limite_transaccion_default'] ?? 5000).toDouble(),
        tipoTarjetaDefault: config['tipo_tarjeta_default'] ?? 'virtual',
        redDefault: config['red_default'] ?? 'visa',
        monedaDefault: config['moneda_default'] ?? 'MXN',
        nombrePrograma: config['nombre_programa'] ?? 'Robert Darin Cards',
        logoUrl: config['logo_url'],
        colorTarjeta: config['color_tarjeta'] ?? '#1E3A8A',
        activo: res['activo'] ?? false,
        verificado: res['estado_conexion'] == 'ok',
        fechaVerificacion: res['ultima_verificacion'] != null 
            ? DateTime.tryParse(res['ultima_verificacion']) 
            : null,
        createdAt: DateTime.parse(res['created_at'] ?? DateTime.now().toIso8601String()),
      );
    } catch (e) {
      debugPrint('Error al obtener configuración de tarjetas: $e');
      return null;
    }
  }

  /// Guardar configuración del proveedor
  /// V10.22: Ahora usa tabla configuracion_apis
  Future<bool> guardarConfiguracion(TarjetasConfigModel config) async {
    try {
      final configJson = {
        'proveedor': config.proveedor,
        'api_base_url': config.apiBaseUrl,
        'webhook_url': config.webhookUrl,
        'account_id': config.accountId,
        'program_id': config.programId,
        'limite_diario_default': config.limiteDiarioDefault,
        'limite_mensual_default': config.limiteMensualDefault,
        'limite_transaccion_default': config.limiteTransaccionDefault,
        'tipo_tarjeta_default': config.tipoTarjetaDefault,
        'red_default': config.redDefault,
        'moneda_default': config.monedaDefault,
        'nombre_programa': config.nombrePrograma,
        'logo_url': config.logoUrl,
        'color_tarjeta': config.colorTarjeta,
      };
      
      await AppSupabase.client.from('configuracion_apis').upsert({
        'negocio_id': config.negocioId,
        'servicio': 'tarjetas_digitales',
        'activo': config.activo,
        'modo_test': config.modoPruebas,
        'api_key': config.apiKey,
        'secret_key': config.apiSecret,
        'webhook_secret': config.webhookSecret,
        'configuracion': configJson,
        'updated_at': DateTime.now().toIso8601String(),
      });
      
      return true;
    } catch (e) {
      debugPrint('Error al guardar configuración: $e');
      return false;
    }
  }

  /// Verificar credenciales del proveedor
  Future<Map<String, dynamic>> verificarCredenciales(TarjetasConfigModel config) async {
    try {
      final proveedor = _obtenerProveedor(config);
      return await proveedor.verificarConexion(config);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // TITULARES (KYC)
  // ═══════════════════════════════════════════════════════════════════════════════

  /// Obtener todos los titulares de un negocio
  Future<List<TarjetaTitularModel>> obtenerTitulares(String negocioId) async {
    try {
      final res = await AppSupabase.client
          .from('tarjetas_titulares')
          .select()
          .eq('negocio_id', negocioId)
          .order('created_at', ascending: false);

      return (res as List).map((e) => TarjetaTitularModel.fromMap(e)).toList();
    } catch (e) {
      debugPrint('Error al obtener titulares: $e');
      return [];
    }
  }

  /// Crear nuevo titular
  Future<TarjetaTitularModel?> crearTitular(TarjetaTitularModel titular) async {
    try {
      final res = await AppSupabase.client
          .from('tarjetas_titulares')
          .insert(titular.toMapForInsert())
          .select()
          .single();

      return TarjetaTitularModel.fromMap(res);
    } catch (e) {
      debugPrint('Error al crear titular: $e');
      return null;
    }
  }

  /// Registrar titular en el proveedor (KYC)
  Future<Map<String, dynamic>> registrarTitularEnProveedor({
    required TarjetasConfigModel config,
    required TarjetaTitularModel titular,
  }) async {
    try {
      final proveedor = _obtenerProveedor(config);
      final resultado = await proveedor.crearTitular(config, titular);
      
      if (resultado['success'] == true && resultado['external_id'] != null) {
        // Actualizar el external_id en la base de datos
        await AppSupabase.client
            .from('tarjetas_titulares')
            .update({
              'external_id': resultado['external_id'],
              'kyc_status': 'en_revision',
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', titular.id);
      }
      
      return resultado;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // TARJETAS
  // ═══════════════════════════════════════════════════════════════════════════════

  /// Obtener todas las tarjetas de un negocio
  Future<List<TarjetaVirtualModel>> obtenerTarjetas(String negocioId) async {
    try {
      final res = await AppSupabase.client
          .from('v_tarjetas_completas')
          .select()
          .eq('negocio_id', negocioId)
          .order('created_at', ascending: false);

      return (res as List).map((e) => TarjetaVirtualModel.fromMap(e)).toList();
    } catch (e) {
      debugPrint('Error al obtener tarjetas: $e');
      return [];
    }
  }

  /// Obtener tarjetas de un titular específico
  Future<List<TarjetaVirtualModel>> obtenerTarjetasPorTitular(String titularId) async {
    try {
      final res = await AppSupabase.client
          .from('v_tarjetas_completas')
          .select()
          .eq('titular_id', titularId)
          .order('created_at', ascending: false);

      return (res as List).map((e) => TarjetaVirtualModel.fromMap(e)).toList();
    } catch (e) {
      debugPrint('Error al obtener tarjetas del titular: $e');
      return [];
    }
  }

  /// Crear nueva tarjeta virtual
  Future<Map<String, dynamic>> crearTarjeta({
    required TarjetasConfigModel config,
    required TarjetaVirtualModel tarjeta,
    required TarjetaTitularModel titular,
  }) async {
    try {
      // Verificar que el titular tenga KYC aprobado
      if (titular.kycStatus != 'aprobado' && !config.modoPruebas) {
        return {'success': false, 'error': 'El titular debe completar el proceso KYC primero'};
      }

      final proveedor = _obtenerProveedor(config);
      final resultado = await proveedor.crearTarjeta(config, tarjeta, titular);
      
      if (resultado['success'] == true) {
        // Guardar en base de datos local
        final nuevaTarjeta = await AppSupabase.client
            .from('tarjetas_virtuales')
            .insert({
              ...tarjeta.toMapForInsert(),
              'external_card_id': resultado['card_id'],
              'numero_tarjeta_masked': resultado['masked_pan'],
              'ultimos_4_digitos': resultado['last_four'],
              'fecha_expiracion': resultado['expiry'],
              'estado': 'activa',
            })
            .select()
            .single();

        resultado['tarjeta'] = TarjetaVirtualModel.fromMap(nuevaTarjeta);
        
        // Log
        await _registrarLog(
          negocioId: tarjeta.negocioId,
          tarjetaId: nuevaTarjeta['id'],
          accion: 'crear_tarjeta',
          descripcion: 'Tarjeta virtual creada',
          resultado: 'exito',
        );
      }
      
      return resultado;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Obtener datos sensibles de la tarjeta (número completo, CVV)
  Future<Map<String, dynamic>> obtenerDatosSensibles({
    required TarjetasConfigModel config,
    required String externalCardId,
  }) async {
    try {
      final proveedor = _obtenerProveedor(config);
      return await proveedor.obtenerDatosSensibles(config, externalCardId);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Bloquear tarjeta
  Future<bool> bloquearTarjeta({
    required TarjetasConfigModel config,
    required TarjetaVirtualModel tarjeta,
    required String motivo,
    required String usuarioId,
  }) async {
    try {
      if (tarjeta.externalCardId != null) {
        final proveedor = _obtenerProveedor(config);
        final resultado = await proveedor.bloquearTarjeta(config, tarjeta.externalCardId!);
        if (resultado['success'] != true) return false;
      }

      await AppSupabase.client
          .from('tarjetas_virtuales')
          .update({
            'estado': 'bloqueada',
            'motivo_bloqueo': motivo,
            'fecha_bloqueo': DateTime.now().toIso8601String(),
            'bloqueado_por': usuarioId,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', tarjeta.id);

      await _registrarLog(
        negocioId: tarjeta.negocioId,
        tarjetaId: tarjeta.id,
        accion: 'bloquear',
        descripcion: 'Tarjeta bloqueada: $motivo',
        resultado: 'exito',
      );

      return true;
    } catch (e) {
      debugPrint('Error al bloquear tarjeta: $e');
      return false;
    }
  }

  /// Desbloquear tarjeta
  Future<bool> desbloquearTarjeta({
    required TarjetasConfigModel config,
    required TarjetaVirtualModel tarjeta,
  }) async {
    try {
      if (tarjeta.externalCardId != null) {
        final proveedor = _obtenerProveedor(config);
        final resultado = await proveedor.desbloquearTarjeta(config, tarjeta.externalCardId!);
        if (resultado['success'] != true) return false;
      }

      await AppSupabase.client
          .from('tarjetas_virtuales')
          .update({
            'estado': 'activa',
            'motivo_bloqueo': null,
            'fecha_bloqueo': null,
            'bloqueado_por': null,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', tarjeta.id);

      await _registrarLog(
        negocioId: tarjeta.negocioId,
        tarjetaId: tarjeta.id,
        accion: 'desbloquear',
        descripcion: 'Tarjeta desbloqueada',
        resultado: 'exito',
      );

      return true;
    } catch (e) {
      debugPrint('Error al desbloquear tarjeta: $e');
      return false;
    }
  }

  /// Actualizar límites de tarjeta
  Future<bool> actualizarLimites({
    required TarjetasConfigModel config,
    required TarjetaVirtualModel tarjeta,
    double? limiteDiario,
    double? limiteMensual,
    double? limiteTransaccion,
  }) async {
    try {
      if (tarjeta.externalCardId != null) {
        final proveedor = _obtenerProveedor(config);
        await proveedor.actualizarLimites(
          config, 
          tarjeta.externalCardId!,
          limiteDiario: limiteDiario,
          limiteMensual: limiteMensual,
          limiteTransaccion: limiteTransaccion,
        );
      }

      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (limiteDiario != null) updates['limite_diario'] = limiteDiario;
      if (limiteMensual != null) updates['limite_mensual'] = limiteMensual;
      if (limiteTransaccion != null) updates['limite_transaccion'] = limiteTransaccion;

      await AppSupabase.client
          .from('tarjetas_virtuales')
          .update(updates)
          .eq('id', tarjeta.id);

      return true;
    } catch (e) {
      debugPrint('Error al actualizar límites: $e');
      return false;
    }
  }

  /// Recargar saldo a tarjeta
  Future<Map<String, dynamic>> recargarTarjeta({
    required TarjetasConfigModel config,
    required TarjetaVirtualModel tarjeta,
    required double monto,
    String? referencia,
  }) async {
    try {
      if (tarjeta.externalCardId != null) {
        final proveedor = _obtenerProveedor(config);
        final resultado = await proveedor.recargarTarjeta(
          config, 
          tarjeta.externalCardId!, 
          monto,
        );
        if (resultado['success'] != true) return resultado;
      }

      // Actualizar saldo local
      await AppSupabase.client
          .from('tarjetas_virtuales')
          .update({
            'saldo_disponible': tarjeta.saldoDisponible + monto,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', tarjeta.id);

      // Registrar recarga
      await AppSupabase.client
          .from('tarjetas_recargas')
          .insert({
            'negocio_id': tarjeta.negocioId,
            'tarjeta_id': tarjeta.id,
            'tipo': 'recarga',
            'monto': monto,
            'estado': 'completada',
            'fecha_completado': DateTime.now().toIso8601String(),
            'saldo_anterior': tarjeta.saldoDisponible,
            'saldo_posterior': tarjeta.saldoDisponible + monto,
            'referencia_pago': referencia,
          });

      await _registrarLog(
        negocioId: tarjeta.negocioId,
        tarjetaId: tarjeta.id,
        accion: 'recargar',
        descripcion: 'Recarga de \$${monto.toStringAsFixed(2)}',
        resultado: 'exito',
      );

      return {'success': true, 'nuevo_saldo': tarjeta.saldoDisponible + monto};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // TRANSACCIONES
  // ═══════════════════════════════════════════════════════════════════════════════

  /// Obtener transacciones de una tarjeta
  Future<List<TarjetaTransaccionModel>> obtenerTransacciones({
    String? tarjetaId,
    String? negocioId,
    int limite = 50,
  }) async {
    try {
      var query = AppSupabase.client
          .from('v_transacciones_completas')
          .select();

      if (tarjetaId != null) {
        query = query.eq('tarjeta_id', tarjetaId);
      }
      if (negocioId != null) {
        query = query.eq('negocio_id', negocioId);
      }

      final res = await query
          .order('fecha_transaccion', ascending: false)
          .limit(limite);

      return (res as List).map((e) => TarjetaTransaccionModel.fromMap(e)).toList();
    } catch (e) {
      debugPrint('Error al obtener transacciones: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // ALERTAS
  // ═══════════════════════════════════════════════════════════════════════════════

  /// Obtener alertas
  Future<List<TarjetaAlertaModel>> obtenerAlertas(String negocioId, {bool soloNoLeidas = false}) async {
    try {
      var query = AppSupabase.client
          .from('tarjetas_alertas')
          .select()
          .eq('negocio_id', negocioId);

      if (soloNoLeidas) {
        query = query.eq('leida', false);
      }

      final res = await query.order('created_at', ascending: false).limit(100);

      return (res as List).map((e) => TarjetaAlertaModel.fromMap(e)).toList();
    } catch (e) {
      debugPrint('Error al obtener alertas: $e');
      return [];
    }
  }

  /// Marcar alerta como leída
  Future<void> marcarAlertaLeida(String alertaId) async {
    await AppSupabase.client
        .from('tarjetas_alertas')
        .update({
          'leida': true,
          'fecha_leida': DateTime.now().toIso8601String(),
        })
        .eq('id', alertaId);
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // ESTADÍSTICAS
  // ═══════════════════════════════════════════════════════════════════════════════

  /// Obtener estadísticas del módulo de tarjetas
  Future<Map<String, dynamic>> obtenerEstadisticas(String negocioId) async {
    try {
      // Total de tarjetas
      final tarjetas = await AppSupabase.client
          .from('tarjetas_virtuales')
          .select('id, estado, saldo_disponible')
          .eq('negocio_id', negocioId);

      final totalTarjetas = (tarjetas as List).length;
      final tarjetasActivas = tarjetas.where((t) => t['estado'] == 'activa').length;
      final saldoTotal = tarjetas.fold<double>(
        0, 
        (sum, t) => sum + ((t['saldo_disponible'] ?? 0) as num).toDouble()
      );

      // Transacciones del mes
      final inicioMes = DateTime(DateTime.now().year, DateTime.now().month, 1);
      final transacciones = await AppSupabase.client
          .from('v_transacciones_completas')
          .select('monto, tipo, estado, fecha_transaccion')
          .eq('negocio_id', negocioId)
          .gte('fecha_transaccion', inicioMes.toIso8601String());

      final gastosMes = (transacciones as List)
          .where((t) => t['tipo'] == 'compra' && t['estado'] == 'completada')
          .fold<double>(0, (sum, t) => sum + ((t['monto'] ?? 0) as num).toDouble());

      return {
        'total_tarjetas': totalTarjetas,
        'tarjetas_activas': tarjetasActivas,
        'saldo_total': saldoTotal,
        'gastos_mes': gastosMes,
        'transacciones_mes': transacciones.length,
      };
    } catch (e) {
      debugPrint('Error al obtener estadísticas: $e');
      return {};
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // HELPERS PRIVADOS
  // ═══════════════════════════════════════════════════════════════════════════════

  /// Obtener instancia del proveedor según configuración
  _TarjetasProveedor _obtenerProveedor(TarjetasConfigModel config) {
    switch (config.proveedor) {
      case 'pomelo':
        return _PomeloProvider();
      case 'rapyd':
        return _RapydProvider();
      case 'stripe':
        return _StripeIssuingProvider();
      case 'galileo':
        return _GalileoProvider();
      default:
        return _PomeloProvider();
    }
  }

  /// Registrar log de operación
  Future<void> _registrarLog({
    required String negocioId,
    String? tarjetaId,
    required String accion,
    String? descripcion,
    required String resultado,
    String? error,
  }) async {
    try {
      await AppSupabase.client.from('tarjetas_log').insert({
        'negocio_id': negocioId,
        'tarjeta_id': tarjetaId,
        'accion': accion,
        'descripcion': descripcion,
        'resultado': resultado,
        'error_mensaje': error,
      });
    } catch (e) {
      debugPrint('Error al registrar log: $e');
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// INTERFAZ ABSTRACTA DE PROVEEDOR
// ═══════════════════════════════════════════════════════════════════════════════

abstract class _TarjetasProveedor {
  Future<Map<String, dynamic>> verificarConexion(TarjetasConfigModel config);
  Future<Map<String, dynamic>> crearTitular(TarjetasConfigModel config, TarjetaTitularModel titular);
  Future<Map<String, dynamic>> crearTarjeta(TarjetasConfigModel config, TarjetaVirtualModel tarjeta, TarjetaTitularModel titular);
  Future<Map<String, dynamic>> obtenerDatosSensibles(TarjetasConfigModel config, String cardId);
  Future<Map<String, dynamic>> bloquearTarjeta(TarjetasConfigModel config, String cardId);
  Future<Map<String, dynamic>> desbloquearTarjeta(TarjetasConfigModel config, String cardId);
  Future<Map<String, dynamic>> actualizarLimites(TarjetasConfigModel config, String cardId, {double? limiteDiario, double? limiteMensual, double? limiteTransaccion});
  Future<Map<String, dynamic>> recargarTarjeta(TarjetasConfigModel config, String cardId, double monto);
}

// ═══════════════════════════════════════════════════════════════════════════════
// PROVEEDOR: POMELO
// ═══════════════════════════════════════════════════════════════════════════════

class _PomeloProvider implements _TarjetasProveedor {
  String _getBaseUrl(bool sandbox) => sandbox 
      ? 'https://api.sandbox.pomelo.la/v1' 
      : 'https://api.pomelo.la/v1';

  Map<String, String> _getHeaders(TarjetasConfigModel config) => {
    'Authorization': 'Bearer ${config.apiKey}',
    'Content-Type': 'application/json',
  };

  @override
  Future<Map<String, dynamic>> verificarConexion(TarjetasConfigModel config) async {
    try {
      final response = await http.get(
        Uri.parse('${_getBaseUrl(config.modoPruebas)}/accounts'),
        headers: _getHeaders(config),
      );
      
      if (response.statusCode == 200 || response.statusCode == 401) {
        return {
          'success': response.statusCode == 200,
          'message': response.statusCode == 200 
              ? 'Conexión exitosa con Pomelo' 
              : 'Credenciales inválidas',
        };
      }
      return {'success': false, 'error': 'Error de conexión: ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  @override
  Future<Map<String, dynamic>> crearTitular(TarjetasConfigModel config, TarjetaTitularModel titular) async {
    try {
      final response = await http.post(
        Uri.parse('${_getBaseUrl(config.modoPruebas)}/users'),
        headers: _getHeaders(config),
        body: jsonEncode({
          'first_name': titular.nombre,
          'last_name': titular.apellidoPaterno ?? '',
          'email': titular.email,
          'phone': titular.telefono,
          'document_type': 'CURP',
          'document_number': titular.curp ?? titular.rfc ?? '',
          'birth_date': titular.fechaNacimiento?.toIso8601String().split('T')[0],
          'nationality': 'MEX',
          'address': {
            'street': titular.calle ?? '',
            'number': titular.numeroExterior ?? '',
            'zip_code': titular.codigoPostal ?? '',
            'city': titular.municipio ?? '',
            'state': titular.estado ?? '',
            'country': 'MEX',
          },
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'external_id': data['id'],
          'data': data,
        };
      }
      return {'success': false, 'error': response.body};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  @override
  Future<Map<String, dynamic>> crearTarjeta(
    TarjetasConfigModel config, 
    TarjetaVirtualModel tarjeta, 
    TarjetaTitularModel titular
  ) async {
    try {
      final response = await http.post(
        Uri.parse('${_getBaseUrl(config.modoPruebas)}/cards'),
        headers: _getHeaders(config),
        body: jsonEncode({
          'user_id': titular.externalId,
          'card_type': tarjeta.tipo == 'virtual' ? 'VIRTUAL' : 'PHYSICAL',
          'affinity_group_id': config.programId,
          'name': tarjeta.nombreTarjeta ?? titular.nombreCompleto,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'card_id': data['id'],
          'masked_pan': data['masked_pan'] ?? '**** **** **** ${data['last_four']}',
          'last_four': data['last_four'],
          'expiry': data['expiration_date'],
          'data': data,
        };
      }
      return {'success': false, 'error': response.body};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  @override
  Future<Map<String, dynamic>> obtenerDatosSensibles(TarjetasConfigModel config, String cardId) async {
    try {
      final response = await http.get(
        Uri.parse('${_getBaseUrl(config.modoPruebas)}/cards/$cardId/sensitive'),
        headers: _getHeaders(config),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'pan': data['pan'],
          'cvv': data['cvv'],
          'expiry': data['expiration_date'],
        };
      }
      return {'success': false, 'error': response.body};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  @override
  Future<Map<String, dynamic>> bloquearTarjeta(TarjetasConfigModel config, String cardId) async {
    try {
      final response = await http.patch(
        Uri.parse('${_getBaseUrl(config.modoPruebas)}/cards/$cardId/block'),
        headers: _getHeaders(config),
      );
      return {'success': response.statusCode == 200};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  @override
  Future<Map<String, dynamic>> desbloquearTarjeta(TarjetasConfigModel config, String cardId) async {
    try {
      final response = await http.patch(
        Uri.parse('${_getBaseUrl(config.modoPruebas)}/cards/$cardId/unblock'),
        headers: _getHeaders(config),
      );
      return {'success': response.statusCode == 200};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  @override
  Future<Map<String, dynamic>> actualizarLimites(
    TarjetasConfigModel config, 
    String cardId, 
    {double? limiteDiario, double? limiteMensual, double? limiteTransaccion}
  ) async {
    try {
      final body = <String, dynamic>{};
      if (limiteDiario != null) body['daily_limit'] = limiteDiario;
      if (limiteMensual != null) body['monthly_limit'] = limiteMensual;
      if (limiteTransaccion != null) body['transaction_limit'] = limiteTransaccion;

      final response = await http.patch(
        Uri.parse('${_getBaseUrl(config.modoPruebas)}/cards/$cardId/limits'),
        headers: _getHeaders(config),
        body: jsonEncode(body),
      );
      return {'success': response.statusCode == 200};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  @override
  Future<Map<String, dynamic>> recargarTarjeta(TarjetasConfigModel config, String cardId, double monto) async {
    try {
      final response = await http.post(
        Uri.parse('${_getBaseUrl(config.modoPruebas)}/cards/$cardId/load'),
        headers: _getHeaders(config),
        body: jsonEncode({
          'amount': monto,
          'currency': 'MXN',
        }),
      );
      return {'success': response.statusCode == 200 || response.statusCode == 201};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PROVEEDOR: RAPYD - IMPLEMENTACIÓN COMPLETA
// Documentación: https://docs.rapyd.net/
// Buena opción para México/LATAM, menos requisitos que Stripe
// ═══════════════════════════════════════════════════════════════════════════════

class _RapydProvider implements _TarjetasProveedor {
  static const String _baseUrl = 'https://api.rapyd.net/v1';
  static const String _sandboxUrl = 'https://sandboxapi.rapyd.net/v1';

  String _getBaseUrl(bool sandbox) => sandbox ? _sandboxUrl : _baseUrl;

  // Rapyd usa HMAC-SHA256 para firmar requests
  String _generateSignature(TarjetasConfigModel config, String method, String path, String body, String salt, String timestamp) {
    final toSign = '$method$path$salt$timestamp${config.apiKey}${config.apiSecret}$body';
    final hmac = Hmac(sha256, utf8.encode(config.apiSecret ?? ''));
    final digest = hmac.convert(utf8.encode(toSign));
    return base64Encode(digest.bytes);
  }

  Map<String, String> _getHeaders(TarjetasConfigModel config, String method, String path, [String body = '']) {
    final salt = _generateSalt();
    final timestamp = (DateTime.now().millisecondsSinceEpoch / 1000).round().toString();
    final signature = _generateSignature(config, method.toLowerCase(), path, body, salt, timestamp);

    return {
      'Content-Type': 'application/json',
      'access_key': config.apiKey ?? '',
      'salt': salt,
      'timestamp': timestamp,
      'signature': signature,
    };
  }

  String _generateSalt() {
    final random = Random.secure();
    final values = List<int>.generate(12, (i) => random.nextInt(256));
    return base64Url.encode(values);
  }

  @override
  Future<Map<String, dynamic>> verificarConexion(TarjetasConfigModel config) async {
    try {
      const path = '/v1/data/countries';
      final response = await http.get(
        Uri.parse('${_getBaseUrl(config.modoPruebas)}$path'),
        headers: _getHeaders(config, 'get', path),
      );
      
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': 'Conexión exitosa con Rapyd',
          'mode': config.modoPruebas ? 'sandbox' : 'production',
        };
      }
      return {'success': false, 'error': 'Error: ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': 'Error de conexión: $e'};
    }
  }

  @override
  Future<Map<String, dynamic>> crearTitular(TarjetasConfigModel config, TarjetaTitularModel titular) async {
    try {
      // Rapyd: Crear un eWallet para el usuario
      const path = '/v1/user';
      final body = jsonEncode({
        'first_name': titular.nombre,
        'last_name': '${titular.apellidoPaterno ?? ''} ${titular.apellidoMaterno ?? ''}'.trim(),
        'email': titular.email,
        'ewallet_reference_id': 'wallet_${titular.id}',
        'phone_number': titular.telefono,
        'type': 'person',
        'contact': {
          'phone_number': titular.telefono,
          'email': titular.email,
          'first_name': titular.nombre,
          'last_name': titular.apellidoPaterno ?? '',
          'contact_type': 'personal',
          'address': {
            'name': titular.nombreCompleto,
            'line_1': '${titular.calle ?? ''} ${titular.numeroExterior ?? ''}',
            'line_2': titular.numeroInterior,
            'city': titular.municipio ?? '',
            'state': titular.estado ?? '',
            'country': 'MX',
            'zip': titular.codigoPostal ?? '',
          },
          'date_of_birth': titular.fechaNacimiento?.toIso8601String().split('T')[0],
          'nationality': 'MX',
          'identification_type': 'PA', // Passport/CURP
          'identification_number': titular.curp ?? titular.rfc ?? '',
        },
      });

      final response = await http.post(
        Uri.parse('${_getBaseUrl(config.modoPruebas)}$path'),
        headers: _getHeaders(config, 'post', path, body),
        body: body,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['status']?['status'] == 'SUCCESS') {
          return {
            'success': true,
            'external_id': data['data']['id'], // ewallet_xxxxx
            'status': data['data']['status'],
            'data': data['data'],
          };
        }
      }
      return {'success': false, 'error': response.body};
    } catch (e) {
      return {'success': false, 'error': 'Error al crear titular: $e'};
    }
  }

  @override
  Future<Map<String, dynamic>> crearTarjeta(
    TarjetasConfigModel config, 
    TarjetaVirtualModel tarjeta, 
    TarjetaTitularModel titular
  ) async {
    try {
      const path = '/v1/issuing/cards';
      final body = jsonEncode({
        'ewallet_contact': titular.externalId,
        'card_program': config.programId ?? 'cardprog_default',
        'metadata': {
          'merchant_defined': true,
          'nombre_tarjeta': tarjeta.nombreTarjeta ?? titular.nombreCompleto,
        },
      });

      final response = await http.post(
        Uri.parse('${_getBaseUrl(config.modoPruebas)}$path'),
        headers: _getHeaders(config, 'post', path, body),
        body: body,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['status']?['status'] == 'SUCCESS') {
          final card = data['data'];
          return {
            'success': true,
            'card_id': card['card_id'],
            'last_four': card['card_number']?.toString().substring(card['card_number'].toString().length - 4),
            'masked_pan': card['masked_card_number'] ?? '**** **** **** ****',
            'expiry': '${card['expiration_month']}/${card['expiration_year']}',
            'status': card['status'],
            'data': card,
          };
        }
      }
      return {'success': false, 'error': response.body};
    } catch (e) {
      return {'success': false, 'error': 'Error al crear tarjeta: $e'};
    }
  }

  @override
  Future<Map<String, dynamic>> obtenerDatosSensibles(TarjetasConfigModel config, String cardId) async {
    try {
      final path = '/v1/issuing/cards/$cardId';
      final response = await http.get(
        Uri.parse('${_getBaseUrl(config.modoPruebas)}$path'),
        headers: _getHeaders(config, 'get', path),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status']?['status'] == 'SUCCESS') {
          final card = data['data'];
          return {
            'success': true,
            'pan': card['card_number'],
            'cvv': card['cvv'],
            'expiry': '${card['expiration_month']}/${card['expiration_year']}',
          };
        }
      }
      return {'success': false, 'error': 'No se pudieron obtener datos sensibles'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  @override
  Future<Map<String, dynamic>> bloquearTarjeta(TarjetasConfigModel config, String cardId) async {
    try {
      final path = '/v1/issuing/cards/$cardId/status';
      final body = jsonEncode({'status': 'BLO'}); // Blocked

      final response = await http.post(
        Uri.parse('${_getBaseUrl(config.modoPruebas)}$path'),
        headers: _getHeaders(config, 'post', path, body),
        body: body,
      );

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Tarjeta bloqueada'};
      }
      return {'success': false, 'error': response.body};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  @override
  Future<Map<String, dynamic>> desbloquearTarjeta(TarjetasConfigModel config, String cardId) async {
    try {
      final path = '/v1/issuing/cards/$cardId/status';
      final body = jsonEncode({'status': 'ACT'}); // Active

      final response = await http.post(
        Uri.parse('${_getBaseUrl(config.modoPruebas)}$path'),
        headers: _getHeaders(config, 'post', path, body),
        body: body,
      );

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Tarjeta desbloqueada'};
      }
      return {'success': false, 'error': response.body};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  @override
  Future<Map<String, dynamic>> actualizarLimites(
    TarjetasConfigModel config, 
    String cardId, 
    {double? limiteDiario, double? limiteMensual, double? limiteTransaccion}
  ) async {
    try {
      final path = '/v1/issuing/cards/$cardId';
      final limits = <String, dynamic>{};
      
      if (limiteDiario != null) limits['daily_limit'] = limiteDiario;
      if (limiteMensual != null) limits['monthly_limit'] = limiteMensual;
      if (limiteTransaccion != null) limits['transaction_limit'] = limiteTransaccion;

      final body = jsonEncode({'spending_limits': limits});

      final response = await http.post(
        Uri.parse('${_getBaseUrl(config.modoPruebas)}$path'),
        headers: _getHeaders(config, 'post', path, body),
        body: body,
      );

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Límites actualizados'};
      }
      return {'success': false, 'error': response.body};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  @override
  Future<Map<String, dynamic>> recargarTarjeta(TarjetasConfigModel config, String cardId, double monto) async {
    try {
      // Rapyd: primero depositar al eWallet, luego fondear la tarjeta
      final path = '/v1/issuing/cards/$cardId/funds';
      final body = jsonEncode({
        'amount': monto,
        'currency': config.monedaDefault.toUpperCase(),
      });

      final response = await http.post(
        Uri.parse('${_getBaseUrl(config.modoPruebas)}$path'),
        headers: _getHeaders(config, 'post', path, body),
        body: body,
      );

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Tarjeta recargada con \$$monto'};
      }
      return {'success': false, 'error': response.body};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PROVEEDOR: STRIPE ISSUING - IMPLEMENTACIÓN COMPLETA V10.52
// Documentación: https://stripe.com/docs/issuing
// Mejor opción para cumplimiento PCI-DSS y marcos regulatorios
// ═══════════════════════════════════════════════════════════════════════════════

class _StripeIssuingProvider implements _TarjetasProveedor {
  static const String _baseUrl = 'https://api.stripe.com/v1';

  Map<String, String> _getHeaders(TarjetasConfigModel config) => {
    'Authorization': 'Bearer ${config.apiKey}',
    'Content-Type': 'application/x-www-form-urlencoded',
    'Stripe-Version': '2024-12-18.acacia',
  };

  @override
  Future<Map<String, dynamic>> verificarConexion(TarjetasConfigModel config) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/balance'),
        headers: _getHeaders(config),
      );
      
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': 'Conexión exitosa con Stripe',
          'mode': config.modoPruebas ? 'test' : 'live',
        };
      }
      return {'success': false, 'error': 'Error: ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': 'Error de conexión: $e'};
    }
  }

  @override
  Future<Map<String, dynamic>> crearTitular(TarjetasConfigModel config, TarjetaTitularModel titular) async {
    try {
      // Stripe Issuing: Crear cardholder
      final body = {
        'type': 'individual',
        'name': titular.nombreCompleto,
        'email': titular.email,
        'phone_number': titular.telefono,
        'billing[address][line1]': '${titular.calle ?? ''} ${titular.numeroExterior ?? ''}'.trim(),
        'billing[address][city]': titular.municipio ?? '',
        'billing[address][state]': titular.estado ?? '',
        'billing[address][country]': 'MX',
        'billing[address][postal_code]': titular.codigoPostal ?? '',
        'individual[first_name]': titular.nombre,
        'individual[last_name]': '${titular.apellidoPaterno ?? ''} ${titular.apellidoMaterno ?? ''}'.trim(),
        if (titular.fechaNacimiento != null) 
          'individual[dob][day]': titular.fechaNacimiento!.day.toString(),
        if (titular.fechaNacimiento != null)
          'individual[dob][month]': titular.fechaNacimiento!.month.toString(),
        if (titular.fechaNacimiento != null)
          'individual[dob][year]': titular.fechaNacimiento!.year.toString(),
        'metadata[cliente_id]': titular.clienteId ?? '',
        'metadata[negocio_id]': titular.negocioId,
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/issuing/cardholders'),
        headers: _getHeaders(config),
        body: body.entries.map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}').join('&'),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'external_id': data['id'], // ich_xxxxx
          'status': data['status'],
          'data': data,
        };
      }
      return {'success': false, 'error': response.body};
    } catch (e) {
      return {'success': false, 'error': 'Error al crear titular: $e'};
    }
  }

  @override
  Future<Map<String, dynamic>> crearTarjeta(
    TarjetasConfigModel config, 
    TarjetaVirtualModel tarjeta, 
    TarjetaTitularModel titular
  ) async {
    try {
      final body = {
        'cardholder': titular.externalId ?? '',
        'currency': 'mxn',
        'type': tarjeta.tipo == 'virtual' ? 'virtual' : 'physical',
        'status': 'active',
        'spending_controls[allowed_categories][]': 'all',
        'spending_controls[spending_limits][][amount]': (tarjeta.limiteDiario * 100).toInt().toString(),
        'spending_controls[spending_limits][][interval]': 'daily',
        'metadata[tarjeta_nombre]': tarjeta.nombreTarjeta ?? '',
        'metadata[titular_id]': tarjeta.titularId,
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/issuing/cards'),
        headers: _getHeaders(config),
        body: body.entries.map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}').join('&'),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'card_id': data['id'], // ic_xxxxx
          'last_four': data['last4'],
          'masked_pan': '**** **** **** ${data['last4']}',
          'expiry': '${data['exp_month']}/${data['exp_year']}',
          'status': data['status'],
          'data': data,
        };
      }
      return {'success': false, 'error': response.body};
    } catch (e) {
      return {'success': false, 'error': 'Error al crear tarjeta: $e'};
    }
  }

  @override
  Future<Map<String, dynamic>> obtenerDatosSensibles(TarjetasConfigModel config, String cardId) async {
    try {
      // Stripe devuelve datos sensibles con expand
      final response = await http.get(
        Uri.parse('$_baseUrl/issuing/cards/$cardId?expand[]=number&expand[]=cvc'),
        headers: _getHeaders(config),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'pan': data['number'],
          'cvv': data['cvc'],
          'expiry': '${data['exp_month']}/${data['exp_year']}',
        };
      }
      return {'success': false, 'error': 'No se pudieron obtener datos sensibles'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  @override
  Future<Map<String, dynamic>> bloquearTarjeta(TarjetasConfigModel config, String cardId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/issuing/cards/$cardId'),
        headers: _getHeaders(config),
        body: 'status=inactive',
      );

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Tarjeta bloqueada'};
      }
      return {'success': false, 'error': response.body};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  @override
  Future<Map<String, dynamic>> desbloquearTarjeta(TarjetasConfigModel config, String cardId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/issuing/cards/$cardId'),
        headers: _getHeaders(config),
        body: 'status=active',
      );

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Tarjeta desbloqueada'};
      }
      return {'success': false, 'error': response.body};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  @override
  Future<Map<String, dynamic>> actualizarLimites(
    TarjetasConfigModel config, 
    String cardId, 
    {double? limiteDiario, double? limiteMensual, double? limiteTransaccion}
  ) async {
    try {
      final limitsBody = <String, String>{};
      
      if (limiteDiario != null) {
        limitsBody['spending_controls[spending_limits][0][amount]'] = (limiteDiario * 100).toInt().toString();
        limitsBody['spending_controls[spending_limits][0][interval]'] = 'daily';
      }
      if (limiteMensual != null) {
        limitsBody['spending_controls[spending_limits][1][amount]'] = (limiteMensual * 100).toInt().toString();
        limitsBody['spending_controls[spending_limits][1][interval]'] = 'monthly';
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/issuing/cards/$cardId'),
        headers: _getHeaders(config),
        body: limitsBody.entries.map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}').join('&'),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Límites actualizados'};
      }
      return {'success': false, 'error': response.body};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  @override
  Future<Map<String, dynamic>> recargarTarjeta(TarjetasConfigModel config, String cardId, double monto) async {
    try {
      // Stripe Issuing usa funding (financiamiento de la cuenta emisora)
      // El saldo se maneja a nivel de cuenta, no por tarjeta individual
      // Para fondear tarjetas se usa Issuing Balance con Top-ups
      
      final response = await http.post(
        Uri.parse('$_baseUrl/topups'),
        headers: _getHeaders(config),
        body: 'amount=${(monto * 100).toInt()}&currency=mxn&description=Recarga+tarjeta+$cardId',
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'message': 'Saldo agregado: \$${monto.toStringAsFixed(2)}'};
      }
      return {'success': false, 'error': response.body};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PROVEEDOR: GALILEO
// Nota: Galileo requiere acuerdo comercial directo
// ═══════════════════════════════════════════════════════════════════════════════

class _GalileoProvider implements _TarjetasProveedor {
  // Galileo requiere contrato enterprise - se recomienda usar Stripe o Rapyd
  
  @override
  Future<Map<String, dynamic>> verificarConexion(TarjetasConfigModel config) async {
    return {
      'success': false, 
      'error': 'Galileo requiere contrato enterprise directo. Recomendamos usar Stripe Issuing o Rapyd.',
      'alternativas': ['stripe', 'rapyd'],
    };
  }

  @override
  Future<Map<String, dynamic>> crearTitular(TarjetasConfigModel config, TarjetaTitularModel titular) async {
    return {'success': false, 'error': 'Use Stripe Issuing o Rapyd como alternativa'};
  }

  @override
  Future<Map<String, dynamic>> crearTarjeta(TarjetasConfigModel config, TarjetaVirtualModel tarjeta, TarjetaTitularModel titular) async {
    return {'success': false, 'error': 'Use Stripe Issuing o Rapyd como alternativa'};
  }

  @override
  Future<Map<String, dynamic>> obtenerDatosSensibles(TarjetasConfigModel config, String cardId) async {
    return {'success': false, 'error': 'Use Stripe Issuing o Rapyd como alternativa'};
  }

  @override
  Future<Map<String, dynamic>> bloquearTarjeta(TarjetasConfigModel config, String cardId) async {
    return {'success': false, 'error': 'Use Stripe Issuing o Rapyd como alternativa'};
  }

  @override
  Future<Map<String, dynamic>> desbloquearTarjeta(TarjetasConfigModel config, String cardId) async {
    return {'success': false, 'error': 'Use Stripe Issuing o Rapyd como alternativa'};
  }

  @override
  Future<Map<String, dynamic>> actualizarLimites(TarjetasConfigModel config, String cardId, {double? limiteDiario, double? limiteMensual, double? limiteTransaccion}) async {
    return {'success': false, 'error': 'Use Stripe Issuing o Rapyd como alternativa'};
  }

  @override
  Future<Map<String, dynamic>> recargarTarjeta(TarjetasConfigModel config, String cardId, double monto) async {
    return {'success': false, 'error': 'Use Stripe Issuing o Rapyd como alternativa'};
  }
}
