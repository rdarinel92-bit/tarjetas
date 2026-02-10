/// ═══════════════════════════════════════════════════════════════════════════════
/// SERVICIO QR COBROS - Robert Darin Fintech V10.7
/// ═══════════════════════════════════════════════════════════════════════════════
/// Servicio para gestionar el sistema de verificación de cobros con QR
/// ═══════════════════════════════════════════════════════════════════════════════

import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../core/supabase_client.dart';
import '../data/models/qr_cobro_model.dart';

class QrCobrosService {
  static final _client = AppSupabase.client;

  /// ═══════════════════════════════════════════════════════════════════════════
  /// GENERACIÓN DE QR
  /// ═══════════════════════════════════════════════════════════════════════════

  /// Genera código QR alfanumérico de 12 caracteres
  static String generarCodigoQr() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return List.generate(12, (_) => chars[random.nextInt(chars.length)]).join();
  }

  /// Genera código de verificación numérico de 6 dígitos
  static String generarCodigoVerificacion() {
    final random = Random.secure();
    return (100000 + random.nextInt(900000)).toString();
  }

  /// Crear un nuevo QR de cobro (llamado por el cobrador)
  static Future<QrCobroModel?> crearQrCobro({
    required String negocioId,
    required String cobradorId,
    required String clienteId,
    required String tipoCobro,
    required String referenciaId,
    String? referenciaTabla,
    required double monto,
    required String concepto,
    String? descripcionAdicional,
    int horasExpiracion = 24,
  }) async {
    try {
      final codigoQr = generarCodigoQr();
      final codigoVerificacion = generarCodigoVerificacion();
      final fechaExpiracion = DateTime.now().add(Duration(hours: horasExpiracion));

      final data = {
        'negocio_id': negocioId,
        'codigo_qr': codigoQr,
        'codigo_verificacion': codigoVerificacion,
        'cobrador_id': cobradorId,
        'cliente_id': clienteId,
        'tipo_cobro': tipoCobro,
        'referencia_id': referenciaId,
        'referencia_tabla': referenciaTabla,
        'monto': monto,
        'concepto': concepto,
        'descripcion_adicional': descripcionAdicional,
        'fecha_expiracion': fechaExpiracion.toIso8601String(),
        'estado': 'pendiente',
      };

      final response = await _client
          .from('qr_cobros')
          .insert(data)
          .select()
          .single();

      return QrCobroModel.fromMap(response);
    } catch (e) {
      debugPrint('Error al crear QR de cobro: $e');
      return null;
    }
  }

  /// ═══════════════════════════════════════════════════════════════════════════
  /// CONFIRMACIONES
  /// ═══════════════════════════════════════════════════════════════════════════

  /// Confirmar cobro por parte del COBRADOR
  static Future<bool> confirmarCobroCobrador({
    required String qrCobroId,
    required double latitud,
    required double longitud,
    String? direccion,
    String? fotoComprobanteUrl,
  }) async {
    try {
      await _client.from('qr_cobros').update({
        'cobrador_confirmo': true,
        'cobrador_confirmo_at': DateTime.now().toIso8601String(),
        'cobrador_latitud': latitud,
        'cobrador_longitud': longitud,
        'cobrador_direccion': direccion,
        'foto_comprobante_url': fotoComprobanteUrl,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', qrCobroId);

      // Verificar si ambos confirmaron
      await _verificarYCompletarCobro(qrCobroId);
      
      return true;
    } catch (e) {
      debugPrint('Error al confirmar cobro (cobrador): $e');
      return false;
    }
  }

  /// Confirmar cobro por parte del CLIENTE (escanea QR)
  static Future<Map<String, dynamic>> confirmarCobroCliente({
    required String codigoQr,
    required String clienteId,
    required double latitud,
    required double longitud,
    String? dispositivo,
    String? firmaDigitalBase64,
  }) async {
    try {
      // Buscar el QR
      final qrData = await _client
          .from('qr_cobros')
          .select()
          .eq('codigo_qr', codigoQr)
          .eq('estado', 'pendiente')
          .maybeSingle();

      if (qrData == null) {
        return {'success': false, 'error': 'QR no válido o ya utilizado'};
      }

      final qr = QrCobroModel.fromMap(qrData);

      // Verificar que es el cliente correcto
      if (qr.clienteId != clienteId) {
        return {'success': false, 'error': 'Este QR no pertenece a tu cuenta'};
      }

      // Verificar expiración
      if (qr.estaExpirado) {
        await _client.from('qr_cobros')
            .update({'estado': 'expirado'})
            .eq('id', qr.id);
        return {'success': false, 'error': 'El código QR ha expirado'};
      }

      // Registrar escaneo
      await _registrarEscaneo(
        qrCobroId: qr.id,
        escaneadoPor: clienteId,
        latitud: latitud,
        longitud: longitud,
        dispositivo: dispositivo,
        resultado: 'exitoso',
      );

      // Actualizar confirmación del cliente
      await _client.from('qr_cobros').update({
        'cliente_confirmo': true,
        'cliente_confirmo_at': DateTime.now().toIso8601String(),
        'cliente_latitud': latitud,
        'cliente_longitud': longitud,
        'cliente_dispositivo': dispositivo,
        'firma_digital_cliente': firmaDigitalBase64,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', qr.id);

      // Verificar si ambos confirmaron
      final completado = await _verificarYCompletarCobro(qr.id);

      return {
        'success': true,
        'qr': qr,
        'completado': completado,
        'message': completado 
            ? 'Pago confirmado exitosamente' 
            : 'Esperando confirmación del cobrador',
      };
    } catch (e) {
      debugPrint('Error al confirmar cobro (cliente): $e');
      return {'success': false, 'error': 'Error al procesar: $e'};
    }
  }

  /// Verificar si ambos confirmaron y completar el cobro
  static Future<bool> _verificarYCompletarCobro(String qrCobroId) async {
    try {
      final qrData = await _client
          .from('qr_cobros')
          .select()
          .eq('id', qrCobroId)
          .single();

      final qr = QrCobroModel.fromMap(qrData);

      if (qr.cobradorConfirmo && qr.clienteConfirmo) {
        // Actualizar estado a confirmado
        await _client.from('qr_cobros').update({
          'estado': 'confirmado',
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', qrCobroId);

        // Aquí se puede llamar a la función para registrar el pago real
        // según el tipo_cobro y referencia_id
        await _registrarPagoSegunTipo(qr);

        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error al verificar cobro: $e');
      return false;
    }
  }

  /// Registrar el pago en la tabla correspondiente según el tipo
  static Future<void> _registrarPagoSegunTipo(QrCobroModel qr) async {
    try {
      String? pagoId;

      switch (qr.tipoCobro) {
        case 'prestamo':
          // Registrar en pagos (préstamos mensuales)
          final pagoData = await _client.from('pagos').insert({
            'negocio_id': qr.negocioId,
            'prestamo_id': qr.referenciaId,
            'monto': qr.monto,
            'metodo_pago': 'efectivo_qr',
            'observaciones': 'Pago verificado con QR: ${qr.codigoQr}',
            'fecha_pago': DateTime.now().toIso8601String(),
            'registrado_por': qr.cobradorId,
          }).select().single();
          pagoId = pagoData['id'];
          break;

        case 'tanda':
          // Registrar pago de tanda
          final pagoData = await _client.from('tanda_pagos').insert({
            'negocio_id': qr.negocioId,
            'tanda_participante_id': qr.referenciaId,
            'monto': qr.monto,
            'metodo_pago': 'efectivo_qr',
            'notas': 'Pago verificado con QR: ${qr.codigoQr}',
            'fecha_pago': DateTime.now().toIso8601String(),
          }).select().single();
          pagoId = pagoData['id'];
          break;

        case 'purificadora':
          // Registrar pago purificadora
          final pagoData = await _client.from('puri_pagos').insert({
            'negocio_id': qr.negocioId,
            'cliente_id': qr.clienteId,
            'monto': qr.monto,
            'metodo_pago': 'efectivo_qr',
            'observaciones': 'Pago verificado con QR: ${qr.codigoQr}',
            'fecha_pago': DateTime.now().toIso8601String(),
          }).select().single();
          pagoId = pagoData['id'];
          break;

        case 'nice':
          // Registrar pago nice
          final pagoData = await _client.from('nice_pagos').insert({
            'negocio_id': qr.negocioId,
            'nice_credito_id': qr.referenciaId,
            'monto': qr.monto,
            'metodo_pago': 'efectivo_qr',
            'notas': 'Pago verificado con QR: ${qr.codigoQr}',
            'fecha_pago': DateTime.now().toIso8601String(),
          }).select().single();
          pagoId = pagoData['id'];
          break;

        case 'ventas':
          // Registrar pago venta
          final pagoData = await _client.from('ventas_pagos').insert({
            'negocio_id': qr.negocioId,
            'venta_id': qr.referenciaId,
            'monto': qr.monto,
            'metodo_pago': 'efectivo_qr',
            'observaciones': 'Pago verificado con QR: ${qr.codigoQr}',
            'fecha_pago': DateTime.now().toIso8601String(),
          }).select().single();
          pagoId = pagoData['id'];
          break;

        case 'climas':
          // Registrar pago climas
          final pagoData = await _client.from('climas_pagos').insert({
            'negocio_id': qr.negocioId,
            'renta_id': qr.referenciaId,
            'monto': qr.monto,
            'metodo_pago': 'efectivo_qr',
            'notas': 'Pago verificado con QR: ${qr.codigoQr}',
            'fecha_pago': DateTime.now().toIso8601String(),
          }).select().single();
          pagoId = pagoData['id'];
          break;
      }

      // Actualizar el QR con el ID del pago registrado
      if (pagoId != null) {
        await _client.from('qr_cobros').update({
          'pago_registrado': true,
          'pago_id': pagoId,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', qr.id);
      }
    } catch (e) {
      debugPrint('Error al registrar pago: $e');
    }
  }

  /// ═══════════════════════════════════════════════════════════════════════════
  /// CONSULTAS
  /// ═══════════════════════════════════════════════════════════════════════════

  /// Obtener QR por código
  static Future<QrCobroModel?> obtenerPorCodigo(String codigoQr) async {
    try {
      final response = await _client
          .from('qr_cobros')
          .select('''
            *,
            clientes:cliente_id(nombre, telefono),
            usuarios:cobrador_id(nombre_completo)
          ''')
          .eq('codigo_qr', codigoQr)
          .maybeSingle();

      if (response == null) return null;
      return QrCobroModel.fromMap(response);
    } catch (e) {
      debugPrint('Error al obtener QR: $e');
      return null;
    }
  }

  /// Obtener QRs pendientes de un cobrador
  static Future<List<QrCobroModel>> obtenerPendientesCobrador(String cobradorId) async {
    try {
      final response = await _client
          .from('qr_cobros')
          .select('''
            *,
            clientes:cliente_id(nombre, telefono)
          ''')
          .eq('cobrador_id', cobradorId)
          .eq('estado', 'pendiente')
          .order('created_at', ascending: false);

      return (response as List)
          .map((e) => QrCobroModel.fromMap(e))
          .toList();
    } catch (e) {
      debugPrint('Error al obtener QRs pendientes: $e');
      return [];
    }
  }

  /// Obtener QRs pendientes de un cliente (para escanear)
  static Future<List<QrCobroModel>> obtenerPendientesCliente(String clienteId) async {
    try {
      final response = await _client
          .from('qr_cobros')
          .select('''
            *,
            usuarios:cobrador_id(nombre_completo)
          ''')
          .eq('cliente_id', clienteId)
          .eq('estado', 'pendiente')
          .order('created_at', ascending: false);

      return (response as List)
          .map((e) => QrCobroModel.fromMap(e))
          .toList();
    } catch (e) {
      debugPrint('Error al obtener QRs cliente: $e');
      return [];
    }
  }

  /// Obtener historial de cobros QR de un negocio
  static Future<List<QrCobroModel>> obtenerHistorialNegocio(
    String negocioId, {
    String? estado,
    DateTime? desde,
    DateTime? hasta,
  }) async {
    try {
      var query = _client
          .from('qr_cobros')
          .select('''
            *,
            clientes:cliente_id(nombre, telefono),
            usuarios:cobrador_id(nombre_completo)
          ''')
          .eq('negocio_id', negocioId);

      if (estado != null) {
        query = query.eq('estado', estado);
      }

      if (desde != null) {
        query = query.gte('created_at', desde.toIso8601String());
      }

      if (hasta != null) {
        query = query.lte('created_at', hasta.toIso8601String());
      }

      final response = await query.order('created_at', ascending: false);

      return (response as List)
          .map((e) => QrCobroModel.fromMap(e))
          .toList();
    } catch (e) {
      debugPrint('Error al obtener historial: $e');
      return [];
    }
  }

  /// Obtener resumen de cobros del día
  static Future<Map<String, dynamic>> obtenerResumenDia(String negocioId) async {
    try {
      final hoy = DateTime.now();
      final inicioDia = DateTime(hoy.year, hoy.month, hoy.day);

      final response = await _client
          .from('qr_cobros')
          .select()
          .eq('negocio_id', negocioId)
          .gte('created_at', inicioDia.toIso8601String());

      final cobros = (response as List).map((e) => QrCobroModel.fromMap(e)).toList();

      final confirmados = cobros.where((c) => c.estado == 'confirmado').toList();
      final pendientes = cobros.where((c) => c.estado == 'pendiente').toList();
      final expirados = cobros.where((c) => c.estado == 'expirado').toList();

      return {
        'total_generados': cobros.length,
        'confirmados': confirmados.length,
        'pendientes': pendientes.length,
        'expirados': expirados.length,
        'monto_confirmado': confirmados.fold<double>(0, (sum, c) => sum + c.monto),
        'monto_pendiente': pendientes.fold<double>(0, (sum, c) => sum + c.monto),
      };
    } catch (e) {
      debugPrint('Error al obtener resumen: $e');
      return {};
    }
  }

  /// ═══════════════════════════════════════════════════════════════════════════
  /// AUDITORÍA
  /// ═══════════════════════════════════════════════════════════════════════════

  /// Registrar escaneo de QR
  static Future<void> _registrarEscaneo({
    required String qrCobroId,
    required String escaneadoPor,
    required double latitud,
    required double longitud,
    String? dispositivo,
    required String resultado,
    String? errorMensaje,
  }) async {
    try {
      await _client.from('qr_cobros_escaneos').insert({
        'qr_cobro_id': qrCobroId,
        'escaneado_por': escaneadoPor,
        'latitud': latitud,
        'longitud': longitud,
        'dispositivo': dispositivo,
        'resultado': resultado,
        'error_mensaje': errorMensaje,
      });
    } catch (e) {
      debugPrint('Error al registrar escaneo: $e');
    }
  }

  /// Reportar problema con un QR
  static Future<bool> reportarProblema({
    required String qrCobroId,
    required String reportadoPor,
    required String tipoProblema,
    required String descripcion,
  }) async {
    try {
      await _client.from('qr_cobros_reportes').insert({
        'qr_cobro_id': qrCobroId,
        'reportado_por': reportadoPor,
        'tipo_problema': tipoProblema,
        'descripcion': descripcion,
      });
      return true;
    } catch (e) {
      debugPrint('Error al reportar problema: $e');
      return false;
    }
  }

  /// ═══════════════════════════════════════════════════════════════════════════
  /// CONFIGURACIÓN
  /// ═══════════════════════════════════════════════════════════════════════════

  /// Obtener configuración de QR para un negocio
  static Future<QrCobrosConfigModel?> obtenerConfig(String negocioId) async {
    try {
      final response = await _client
          .from('qr_cobros_config')
          .select()
          .eq('negocio_id', negocioId)
          .maybeSingle();

      if (response == null) return null;
      return QrCobrosConfigModel.fromMap(response);
    } catch (e) {
      debugPrint('Error al obtener config: $e');
      return null;
    }
  }

  /// Guardar configuración de QR
  static Future<bool> guardarConfig(QrCobrosConfigModel config) async {
    try {
      await _client
          .from('qr_cobros_config')
          .upsert(config.toMap());
      return true;
    } catch (e) {
      debugPrint('Error al guardar config: $e');
      return false;
    }
  }

  /// ═══════════════════════════════════════════════════════════════════════════
  /// UTILIDADES PARA QR
  /// ═══════════════════════════════════════════════════════════════════════════

  /// Genera los datos para el código QR (JSON)
  static String generarDatosQr(QrCobroModel qr) {
    return jsonEncode({
      'app': 'robertdarin',
      'type': 'cobro',
      'code': qr.codigoQr,
      'v': qr.codigoVerificacion,
      'amount': qr.monto,
    });
  }

  /// Parsear datos de un QR escaneado
  static Map<String, dynamic>? parsearDatosQr(String qrData) {
    try {
      final data = jsonDecode(qrData);
      if (data['app'] == 'robertdarin' && data['type'] == 'cobro') {
        return data;
      }
      return null;
    } catch (e) {
      // Puede ser un código simple
      if (qrData.length == 12 && RegExp(r'^[A-Z0-9]+$').hasMatch(qrData)) {
        return {'code': qrData};
      }
      return null;
    }
  }

  /// Cancelar un QR de cobro
  static Future<bool> cancelarQr(String qrCobroId, {String? motivo}) async {
    try {
      await _client.from('qr_cobros').update({
        'estado': 'cancelado',
        'descripcion_adicional': motivo ?? 'Cancelado por el usuario',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', qrCobroId);
      return true;
    } catch (e) {
      debugPrint('Error al cancelar QR: $e');
      return false;
    }
  }

  /// Rechazar confirmación del cliente
  static Future<bool> rechazarCobro(String qrCobroId, String clienteId, String motivo) async {
    try {
      await _client.from('qr_cobros').update({
        'estado': 'rechazado',
        'descripcion_adicional': 'Rechazado por cliente: $motivo',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', qrCobroId).eq('cliente_id', clienteId);
      return true;
    } catch (e) {
      debugPrint('Error al rechazar cobro: $e');
      return false;
    }
  }
}
