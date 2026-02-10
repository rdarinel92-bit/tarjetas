import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import '../core/supabase_client.dart';

/// ══════════════════════════════════════════════════════════════════════════════
/// SERVICIO DE AUDITORÍA LEGAL Y EVIDENCIAS PARA JUICIOS
/// ══════════════════════════════════════════════════════════════════════════════
/// Este servicio genera y almacena toda la evidencia necesaria para procesos
/// legales contra clientes morosos. Incluye:
/// - Cadena de custodia digital
/// - Hashes SHA-256 de documentos
/// - Timestamps certificados
/// - Historial completo de comunicaciones
/// - Registro de geolocalización
/// - Estados de cuenta certificados
/// ══════════════════════════════════════════════════════════════════════════════

class AuditoriaLegalService {
  static final AuditoriaLegalService _instance = AuditoriaLegalService._internal();
  factory AuditoriaLegalService() => _instance;
  AuditoriaLegalService._internal();

  final _supabase = AppSupabase.client;

  // ══════════════════════════════════════════════════════════════════════════
  // GENERACIÓN DE EXPEDIENTE LEGAL COMPLETO
  // ══════════════════════════════════════════════════════════════════════════

  /// Genera un expediente legal completo para un préstamo moroso
  /// Incluye toda la evidencia necesaria para un juicio
  Future<ExpedienteLegal> generarExpedienteLegal({
    required String prestamoId,
    required String clienteId,
  }) async {
    try {
      final expediente = ExpedienteLegal(
        prestamoId: prestamoId,
        clienteId: clienteId,
        fechaGeneracion: DateTime.now(),
      );

      // 1. Información del cliente
      expediente.infoCliente = await _obtenerInfoCliente(clienteId);
      
      // 2. Información del préstamo
      expediente.infoPrestamo = await _obtenerInfoPrestamo(prestamoId);
      
      // 3. Contrato firmado
      expediente.contratoFirmado = await _obtenerContratoFirmado(prestamoId);
      
      // 4. Pagaré firmado
      expediente.pagareFirmado = await _obtenerPagareFirmado(prestamoId);
      
      // 5. Historial de pagos
      expediente.historialPagos = await _obtenerHistorialPagos(prestamoId);
      
      // 6. Estado de cuenta actual
      expediente.estadoCuenta = await _generarEstadoCuenta(prestamoId);
      
      // 7. Historial de comunicaciones (intentos de cobro)
      expediente.comunicaciones = await _obtenerComunicaciones(prestamoId, clienteId);
      
      // 8. Notificaciones de mora enviadas
      expediente.notificacionesMora = await _obtenerNotificacionesMora(prestamoId);
      
      // 9. Evidencia de avales
      expediente.evidenciaAvales = await _obtenerEvidenciaAvales(prestamoId);
      
      // 10. Registro de ubicaciones (si consintió)
      expediente.registroUbicaciones = await _obtenerRegistroUbicaciones(clienteId);
      
      // 11. Auditoría de acceso del cliente
      expediente.auditoriaAcceso = await _obtenerAuditoriaAcceso(clienteId);
      
      // 12. Generar hash del expediente completo
      expediente.hashExpediente = _generarHashExpediente(expediente);
      
      // 13. Guardar expediente en BD
      await _guardarExpediente(expediente);
      
      return expediente;
    } catch (e) {
      debugPrint('Error generando expediente legal: $e');
      rethrow;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // OBTENCIÓN DE DATOS
  // ══════════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> _obtenerInfoCliente(String clienteId) async {
    final res = await _supabase
        .from('clientes')
        .select('''
          *,
          usuarios(email, telefono),
          documentos_cliente(tipo_documento, documento_url, verificado, created_at)
        ''')
        .eq('id', clienteId)
        .single();
    
    return {
      ...res,
      'hash_datos': _generarHash(jsonEncode(res)),
      'fecha_extraccion': DateTime.now().toIso8601String(),
    };
  }

  Future<Map<String, dynamic>> _obtenerInfoPrestamo(String prestamoId) async {
    final res = await _supabase
        .from('prestamos')
        .select('''
          *,
          clientes(nombre_completo, curp, rfc),
          usuarios(nombre_completo)
        ''')
        .eq('id', prestamoId)
        .single();
    
    return {
      ...res,
      'hash_datos': _generarHash(jsonEncode(res)),
      'fecha_extraccion': DateTime.now().toIso8601String(),
    };
  }

  Future<DocumentoLegal?> _obtenerContratoFirmado(String prestamoId) async {
    final res = await _supabase
        .from('comprobantes_prestamo')
        .select()
        .eq('prestamo_id', prestamoId)
        .eq('tipo', 'contrato')
        .maybeSingle();
    
    if (res == null) return null;
    
    return DocumentoLegal(
      tipo: 'contrato',
      url: res['archivo_url'],
      hashOriginal: res['hash_archivo'],
      fechaFirma: res['firmado_at'] != null ? DateTime.parse(res['firmado_at']) : null,
      firmaDigital: res['firma_digital'],
      ipFirma: res['ip_firma'],
    );
  }

  Future<DocumentoLegal?> _obtenerPagareFirmado(String prestamoId) async {
    final res = await _supabase
        .from('comprobantes_prestamo')
        .select()
        .eq('prestamo_id', prestamoId)
        .eq('tipo', 'pagare')
        .maybeSingle();
    
    if (res == null) return null;
    
    return DocumentoLegal(
      tipo: 'pagare',
      url: res['archivo_url'],
      hashOriginal: res['hash_archivo'],
      fechaFirma: res['firmado_at'] != null ? DateTime.parse(res['firmado_at']) : null,
      firmaDigital: res['firma_digital'],
      ipFirma: res['ip_firma'],
    );
  }

  Future<List<Map<String, dynamic>>> _obtenerHistorialPagos(String prestamoId) async {
    final res = await _supabase
        .from('pagos')
        .select('''
          *,
          usuarios(nombre_completo)
        ''')
        .eq('prestamo_id', prestamoId)
        .order('fecha_pago', ascending: true);
    
    return List<Map<String, dynamic>>.from(res).map((pago) {
      return {
        ...pago,
        'hash_registro': _generarHash(jsonEncode(pago)),
      };
    }).toList();
  }

  Future<EstadoCuenta> _generarEstadoCuenta(String prestamoId) async {
    final prestamo = await _supabase
        .from('prestamos')
        .select()
        .eq('id', prestamoId)
        .single();
    
    final pagos = await _supabase
        .from('pagos')
        .select()
        .eq('prestamo_id', prestamoId)
        .eq('estado', 'confirmado');
    
    double totalPagado = 0;
    for (var pago in pagos) {
      totalPagado += (pago['monto'] ?? 0).toDouble();
    }
    
    final montoTotal = (prestamo['monto_total'] ?? 0).toDouble();
    final saldoPendiente = montoTotal - totalPagado;
    
    // Calcular días de mora
    final fechaVencimiento = DateTime.parse(prestamo['fecha_fin']);
    final diasMora = DateTime.now().difference(fechaVencimiento).inDays;
    
    // Calcular intereses moratorios (ejemplo: 2% mensual)
    final tasaMoratoria = 0.02; // 2% mensual
    final mesesMora = (diasMora / 30).ceil();
    final interesesMoratorios = saldoPendiente * tasaMoratoria * mesesMora;
    
    return EstadoCuenta(
      prestamoId: prestamoId,
      montoOriginal: (prestamo['monto'] ?? 0).toDouble(),
      montoTotal: montoTotal,
      totalPagado: totalPagado,
      saldoPendiente: saldoPendiente,
      diasMora: diasMora > 0 ? diasMora : 0,
      interesesMoratorios: interesesMoratorios > 0 ? interesesMoratorios : 0,
      totalAdeudado: saldoPendiente + (interesesMoratorios > 0 ? interesesMoratorios : 0),
      fechaCorte: DateTime.now(),
      hashEstado: _generarHash('$prestamoId|$saldoPendiente|$diasMora|${DateTime.now().toIso8601String()}'),
    );
  }

  Future<List<Comunicacion>> _obtenerComunicaciones(String prestamoId, String clienteId) async {
    final comunicaciones = <Comunicacion>[];
    
    // 1. Mensajes de chat con el cliente
    final chats = await _supabase
        .from('conversaciones')
        .select('id')
        .or('cliente_id.eq.$clienteId,prestamo_id.eq.$prestamoId');
    
    for (var chat in chats) {
      final mensajes = await _supabase
          .from('mensajes')
          .select('*, usuarios(nombre_completo)')
          .eq('conversacion_id', chat['id'])
          .order('created_at', ascending: true);
      
      for (var msg in mensajes) {
        comunicaciones.add(Comunicacion(
          tipo: 'chat',
          fecha: DateTime.parse(msg['created_at']),
          contenido: msg['contenido'],
          remitente: msg['usuarios']?['nombre_completo'] ?? 'Sistema',
          leido: msg['leido'] ?? false,
          hashMensaje: _generarHash(jsonEncode(msg)),
        ));
      }
    }
    
    // 2. Notificaciones push enviadas
    final notifs = await _supabase
        .from('notificaciones')
        .select()
        .eq('usuario_id', clienteId)
        .order('created_at', ascending: true);
    
    for (var notif in notifs) {
      comunicaciones.add(Comunicacion(
        tipo: 'notificacion_push',
        fecha: DateTime.parse(notif['created_at']),
        contenido: '${notif['titulo']}: ${notif['mensaje']}',
        remitente: 'Sistema',
        leido: notif['leido'] ?? false,
        hashMensaje: _generarHash(jsonEncode(notif)),
      ));
    }
    
    // Ordenar por fecha
    comunicaciones.sort((a, b) => a.fecha.compareTo(b.fecha));
    
    return comunicaciones;
  }

  Future<List<Map<String, dynamic>>> _obtenerNotificacionesMora(String prestamoId) async {
    final res = await _supabase
        .from('notificaciones_mora')
        .select()
        .eq('prestamo_id', prestamoId)
        .order('fecha_envio', ascending: true);
    
    return List<Map<String, dynamic>>.from(res).map((n) {
      return {
        ...n,
        'hash_notificacion': _generarHash(jsonEncode(n)),
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _obtenerEvidenciaAvales(String prestamoId) async {
    final avales = await _supabase
        .from('prestamos_avales')
        .select('''
          *,
          avales(
            nombre, telefono, email, curp, direccion,
            documentos_aval(tipo, archivo_url, firmado, fecha_firma)
          )
        ''')
        .eq('prestamo_id', prestamoId);
    
    return List<Map<String, dynamic>>.from(avales).map((a) {
      return {
        ...a,
        'hash_aval': _generarHash(jsonEncode(a)),
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _obtenerRegistroUbicaciones(String clienteId) async {
    // Obtener usuario_id del cliente
    final cliente = await _supabase
        .from('clientes')
        .select('usuario_id')
        .eq('id', clienteId)
        .maybeSingle();
    
    if (cliente == null) return [];
    
    final res = await _supabase
        .from('auditoria_acceso')
        .select('latitud, longitud, created_at, accion, dispositivo, ip')
        .eq('usuario_id', cliente['usuario_id'])
        .not('latitud', 'is', null)
        .order('created_at', ascending: false)
        .limit(100);
    
    return List<Map<String, dynamic>>.from(res);
  }

  Future<List<Map<String, dynamic>>> _obtenerAuditoriaAcceso(String clienteId) async {
    final cliente = await _supabase
        .from('clientes')
        .select('usuario_id')
        .eq('id', clienteId)
        .maybeSingle();
    
    if (cliente == null) return [];
    
    final res = await _supabase
        .from('auditoria_acceso')
        .select()
        .eq('usuario_id', cliente['usuario_id'])
        .order('created_at', ascending: false)
        .limit(500);
    
    return List<Map<String, dynamic>>.from(res).map((a) {
      return {
        ...a,
        'hash_registro': _generarHash(jsonEncode(a)),
      };
    }).toList();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // FUNCIONES DE HASH Y SEGURIDAD
  // ══════════════════════════════════════════════════════════════════════════

  String _generarHash(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  String _generarHashExpediente(ExpedienteLegal expediente) {
    final data = {
      'prestamoId': expediente.prestamoId,
      'clienteId': expediente.clienteId,
      'fechaGeneracion': expediente.fechaGeneracion.toIso8601String(),
      'estadoCuenta': expediente.estadoCuenta?.hashEstado,
      'contratoHash': expediente.contratoFirmado?.hashOriginal,
      'pagareHash': expediente.pagareFirmado?.hashOriginal,
      'numPagos': expediente.historialPagos.length,
      'numComunicaciones': expediente.comunicaciones.length,
    };
    return _generarHash(jsonEncode(data));
  }

  Future<void> _guardarExpediente(ExpedienteLegal expediente) async {
    await _supabase.from('expedientes_legales').insert({
      'prestamo_id': expediente.prestamoId,
      'cliente_id': expediente.clienteId,
      'fecha_generacion': expediente.fechaGeneracion.toIso8601String(),
      'hash_expediente': expediente.hashExpediente,
      'estado_cuenta': expediente.estadoCuenta?.toJson(),
      'num_comunicaciones': expediente.comunicaciones.length,
      'num_pagos': expediente.historialPagos.length,
      'total_adeudado': expediente.estadoCuenta?.totalAdeudado,
      'dias_mora': expediente.estadoCuenta?.diasMora,
    });
    
    // Registrar en auditoría legal
    await _supabase.from('auditoria_legal').insert({
      'prestamo_id': expediente.prestamoId,
      'cliente_id': expediente.clienteId,
      'tipo_evento': 'generacion_expediente_legal',
      'descripcion': 'Expediente legal generado para proceso judicial',
      'hash_documento': expediente.hashExpediente,
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  // REGISTRO DE EVENTOS LEGALES EN TIEMPO REAL
  // ══════════════════════════════════════════════════════════════════════════

  /// Registra cualquier acción legalmente relevante
  Future<void> registrarEventoLegal({
    required String prestamoId,
    required String clienteId,
    required String tipoEvento,
    required String descripcion,
    String? documentoUrl,
    String? ipUsuario,
    Map<String, dynamic>? metadatos,
  }) async {
    final hashContenido = _generarHash(
      '$prestamoId|$clienteId|$tipoEvento|$descripcion|${DateTime.now().toIso8601String()}'
    );
    
    await _supabase.from('auditoria_legal').insert({
      'prestamo_id': prestamoId,
      'cliente_id': clienteId,
      'tipo_evento': tipoEvento,
      'descripcion': descripcion,
      'documento_url': documentoUrl,
      'hash_documento': hashContenido,
      'ip_usuario': ipUsuario,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Registra la firma digital de un documento
  Future<void> registrarFirmaDigital({
    required String prestamoId,
    required String tipoDocumento,
    required String firmaDigital,
    required String ipUsuario,
    required String documentoUrl,
  }) async {
    // Generar hash del documento
    final hashDocumento = _generarHash('$documentoUrl|$firmaDigital|${DateTime.now().toIso8601String()}');
    
    // Guardar comprobante
    await _supabase.from('comprobantes_prestamo').insert({
      'prestamo_id': prestamoId,
      'tipo': tipoDocumento,
      'archivo_url': documentoUrl,
      'hash_archivo': hashDocumento,
      'firma_digital': firmaDigital,
      'firmado_at': DateTime.now().toIso8601String(),
      'ip_firma': ipUsuario,
    });
    
    // Registrar en auditoría legal
    await registrarEventoLegal(
      prestamoId: prestamoId,
      clienteId: '', // Se puede obtener del préstamo
      tipoEvento: 'firma_documento',
      descripcion: 'Documento $tipoDocumento firmado digitalmente',
      documentoUrl: documentoUrl,
      ipUsuario: ipUsuario,
    );
  }

  /// Registra un intento de cobro
  Future<void> registrarIntentoCobro({
    required String prestamoId,
    required String clienteId,
    required String tipoCobro, // llamada, visita, mensaje, notificacion
    required String resultado, // contestado, no_contestado, promesa_pago, negado
    String? notas,
    double? latitud,
    double? longitud,
  }) async {
    await _supabase.from('intentos_cobro').upsert({
      'prestamo_id': prestamoId,
      'cliente_id': clienteId,
      'tipo': tipoCobro,
      'resultado': resultado,
      'notas': notas,
      'latitud': latitud,
      'longitud': longitud,
      'fecha': DateTime.now().toIso8601String(),
      'hash_registro': _generarHash('$prestamoId|$tipoCobro|$resultado|${DateTime.now().toIso8601String()}'),
    });
    
    await registrarEventoLegal(
      prestamoId: prestamoId,
      clienteId: clienteId,
      tipoEvento: 'intento_cobro',
      descripcion: 'Intento de cobro tipo $tipoCobro con resultado: $resultado',
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // GENERACIÓN DE REPORTES LEGALES
  // ══════════════════════════════════════════════════════════════════════════

  /// Genera reporte de cartera vencida con evidencia legal
  Future<List<ReporteMoroso>> generarReporteCarteraVencida({
    int diasMinMora = 30,
    double montoMinimo = 0,
  }) async {
    final prestamos = await _supabase
        .from('prestamos')
        .select('''
          *,
          clientes(nombre_completo, telefono, email, curp, direccion)
        ''')
        .eq('estado', 'activo')
        .lt('fecha_fin', DateTime.now().toIso8601String());
    
    final reportes = <ReporteMoroso>[];
    
    for (var prestamo in prestamos) {
      final fechaFin = DateTime.parse(prestamo['fecha_fin']);
      final diasMora = DateTime.now().difference(fechaFin).inDays;
      
      if (diasMora < diasMinMora) continue;
      
      // Calcular saldo pendiente
      final pagos = await _supabase
          .from('pagos')
          .select('monto')
          .eq('prestamo_id', prestamo['id'])
          .eq('estado', 'confirmado');
      
      double totalPagado = 0;
      for (var p in pagos) {
        totalPagado += (p['monto'] ?? 0).toDouble();
      }
      
      final saldoPendiente = (prestamo['monto_total'] ?? 0).toDouble() - totalPagado;
      
      if (saldoPendiente < montoMinimo) continue;
      
      // Contar intentos de cobro
      final intentos = await _supabase
          .from('intentos_cobro')
          .select('id')
          .eq('prestamo_id', prestamo['id']);
      
      // Contar comunicaciones
      final cliente = prestamo['clientes'];
      
      reportes.add(ReporteMoroso(
        prestamoId: prestamo['id'],
        clienteNombre: cliente?['nombre_completo'] ?? '',
        clienteTelefono: cliente?['telefono'] ?? '',
        clienteEmail: cliente?['email'] ?? '',
        clienteCurp: cliente?['curp'] ?? '',
        montoOriginal: (prestamo['monto'] ?? 0).toDouble(),
        saldoPendiente: saldoPendiente,
        diasMora: diasMora,
        intentosCobro: intentos.length,
        fechaVencimiento: fechaFin,
        estadoLegal: _determinarEstadoLegal(diasMora, intentos.length),
      ));
    }
    
    // Ordenar por días de mora descendente
    reportes.sort((a, b) => b.diasMora.compareTo(a.diasMora));
    
    return reportes;
  }

  String _determinarEstadoLegal(int diasMora, int intentosCobro) {
    if (diasMora > 180 && intentosCobro >= 5) {
      return 'LISTO_PARA_DEMANDA';
    } else if (diasMora > 90 && intentosCobro >= 3) {
      return 'PREPARAR_EXPEDIENTE';
    } else if (diasMora > 60) {
      return 'COBRANZA_PREJUDICIAL';
    } else if (diasMora > 30) {
      return 'COBRANZA_EXTRAJUDICIAL';
    }
    return 'COBRANZA_ADMINISTRATIVA';
  }

  /// Obtiene resumen de evidencias disponibles para un préstamo
  Future<ResumenEvidencias> obtenerResumenEvidencias(String prestamoId) async {
    // Contrato
    final contrato = await _supabase
        .from('comprobantes_prestamo')
        .select()
        .eq('prestamo_id', prestamoId)
        .eq('tipo', 'contrato')
        .maybeSingle();
    
    // Pagaré
    final pagare = await _supabase
        .from('comprobantes_prestamo')
        .select()
        .eq('prestamo_id', prestamoId)
        .eq('tipo', 'pagare')
        .maybeSingle();
    
    // INE del cliente
    final prestamo = await _supabase
        .from('prestamos')
        .select('cliente_id')
        .eq('id', prestamoId)
        .single();
    
    final ineCliente = await _supabase
        .from('documentos_cliente')
        .select()
        .eq('cliente_id', prestamo['cliente_id'])
        .eq('tipo_documento', 'INE')
        .maybeSingle();
    
    // Comprobante domicilio
    final comprobanteDom = await _supabase
        .from('documentos_cliente')
        .select()
        .eq('cliente_id', prestamo['cliente_id'])
        .eq('tipo_documento', 'comprobante_domicilio')
        .maybeSingle();
    
    // Pagos
    final pagos = await _supabase
        .from('pagos')
        .select()
        .eq('prestamo_id', prestamoId);
    
    // Intentos de cobro
    final intentos = await _supabase
        .from('intentos_cobro')
        .select()
        .eq('prestamo_id', prestamoId);
    
    // Comunicaciones
    final notificaciones = await _supabase
        .from('notificaciones_mora')
        .select()
        .eq('prestamo_id', prestamoId);
    
    // Avales
    final avales = await _supabase
        .from('prestamos_avales')
        .select('*, avales(documentos_aval(id))')
        .eq('prestamo_id', prestamoId);
    
    return ResumenEvidencias(
      tieneContrato: contrato != null,
      contratoFirmado: contrato?['firma_digital'] != null,
      tienePagare: pagare != null,
      pagareFirmado: pagare?['firma_digital'] != null,
      tieneIneCliente: ineCliente != null,
      tieneComprobanteDomicilio: comprobanteDom != null,
      numPagosRegistrados: pagos.length,
      numIntentosCobro: intentos.length,
      numNotificacionesMora: notificaciones.length,
      numAvales: avales.length,
      avalesConDocumentos: avales.where((a) => 
        (a['avales']?['documentos_aval'] as List?)?.isNotEmpty ?? false
      ).length,
      listoParaDemanda: _evaluarListoParaDemanda(
        tieneContrato: contrato != null,
        contratoFirmado: contrato?['firma_digital'] != null,
        tienePagare: pagare != null,
        intentosCobro: intentos.length,
        notificaciones: notificaciones.length,
      ),
    );
  }

  bool _evaluarListoParaDemanda({
    required bool tieneContrato,
    required bool contratoFirmado,
    required bool tienePagare,
    required int intentosCobro,
    required int notificaciones,
  }) {
    // Requisitos mínimos para demanda:
    // 1. Contrato firmado O pagaré
    // 2. Al menos 3 intentos de cobro documentados
    // 3. Al menos 2 notificaciones de mora
    return (contratoFirmado || tienePagare) && 
           intentosCobro >= 3 && 
           notificaciones >= 2;
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// MODELOS DE DATOS
// ══════════════════════════════════════════════════════════════════════════════

class ExpedienteLegal {
  final String prestamoId;
  final String clienteId;
  final DateTime fechaGeneracion;
  
  Map<String, dynamic>? infoCliente;
  Map<String, dynamic>? infoPrestamo;
  DocumentoLegal? contratoFirmado;
  DocumentoLegal? pagareFirmado;
  List<Map<String, dynamic>> historialPagos = [];
  EstadoCuenta? estadoCuenta;
  List<Comunicacion> comunicaciones = [];
  List<Map<String, dynamic>> notificacionesMora = [];
  List<Map<String, dynamic>> evidenciaAvales = [];
  List<Map<String, dynamic>> registroUbicaciones = [];
  List<Map<String, dynamic>> auditoriaAcceso = [];
  String? hashExpediente;

  ExpedienteLegal({
    required this.prestamoId,
    required this.clienteId,
    required this.fechaGeneracion,
  });

  Map<String, dynamic> toJson() => {
    'prestamo_id': prestamoId,
    'cliente_id': clienteId,
    'fecha_generacion': fechaGeneracion.toIso8601String(),
    'hash_expediente': hashExpediente,
    'info_cliente': infoCliente,
    'info_prestamo': infoPrestamo,
    'contrato': contratoFirmado?.toJson(),
    'pagare': pagareFirmado?.toJson(),
    'historial_pagos': historialPagos,
    'estado_cuenta': estadoCuenta?.toJson(),
    'comunicaciones': comunicaciones.map((c) => c.toJson()).toList(),
    'notificaciones_mora': notificacionesMora,
    'evidencia_avales': evidenciaAvales,
    'registro_ubicaciones': registroUbicaciones,
    'auditoria_acceso': auditoriaAcceso,
  };
}

class DocumentoLegal {
  final String tipo;
  final String? url;
  final String? hashOriginal;
  final DateTime? fechaFirma;
  final String? firmaDigital;
  final String? ipFirma;

  DocumentoLegal({
    required this.tipo,
    this.url,
    this.hashOriginal,
    this.fechaFirma,
    this.firmaDigital,
    this.ipFirma,
  });

  Map<String, dynamic> toJson() => {
    'tipo': tipo,
    'url': url,
    'hash_original': hashOriginal,
    'fecha_firma': fechaFirma?.toIso8601String(),
    'firma_digital': firmaDigital,
    'ip_firma': ipFirma,
  };
}

class EstadoCuenta {
  final String prestamoId;
  final double montoOriginal;
  final double montoTotal;
  final double totalPagado;
  final double saldoPendiente;
  final int diasMora;
  final double interesesMoratorios;
  final double totalAdeudado;
  final DateTime fechaCorte;
  final String hashEstado;

  EstadoCuenta({
    required this.prestamoId,
    required this.montoOriginal,
    required this.montoTotal,
    required this.totalPagado,
    required this.saldoPendiente,
    required this.diasMora,
    required this.interesesMoratorios,
    required this.totalAdeudado,
    required this.fechaCorte,
    required this.hashEstado,
  });

  Map<String, dynamic> toJson() => {
    'prestamo_id': prestamoId,
    'monto_original': montoOriginal,
    'monto_total': montoTotal,
    'total_pagado': totalPagado,
    'saldo_pendiente': saldoPendiente,
    'dias_mora': diasMora,
    'intereses_moratorios': interesesMoratorios,
    'total_adeudado': totalAdeudado,
    'fecha_corte': fechaCorte.toIso8601String(),
    'hash_estado': hashEstado,
  };
}

class Comunicacion {
  final String tipo;
  final DateTime fecha;
  final String contenido;
  final String remitente;
  final bool leido;
  final String hashMensaje;

  Comunicacion({
    required this.tipo,
    required this.fecha,
    required this.contenido,
    required this.remitente,
    required this.leido,
    required this.hashMensaje,
  });

  Map<String, dynamic> toJson() => {
    'tipo': tipo,
    'fecha': fecha.toIso8601String(),
    'contenido': contenido,
    'remitente': remitente,
    'leido': leido,
    'hash_mensaje': hashMensaje,
  };
}

class ReporteMoroso {
  final String prestamoId;
  final String clienteNombre;
  final String clienteTelefono;
  final String clienteEmail;
  final String clienteCurp;
  final double montoOriginal;
  final double saldoPendiente;
  final int diasMora;
  final int intentosCobro;
  final DateTime fechaVencimiento;
  final String estadoLegal;

  ReporteMoroso({
    required this.prestamoId,
    required this.clienteNombre,
    required this.clienteTelefono,
    required this.clienteEmail,
    required this.clienteCurp,
    required this.montoOriginal,
    required this.saldoPendiente,
    required this.diasMora,
    required this.intentosCobro,
    required this.fechaVencimiento,
    required this.estadoLegal,
  });
}

class ResumenEvidencias {
  final bool tieneContrato;
  final bool contratoFirmado;
  final bool tienePagare;
  final bool pagareFirmado;
  final bool tieneIneCliente;
  final bool tieneComprobanteDomicilio;
  final int numPagosRegistrados;
  final int numIntentosCobro;
  final int numNotificacionesMora;
  final int numAvales;
  final int avalesConDocumentos;
  final bool listoParaDemanda;

  ResumenEvidencias({
    required this.tieneContrato,
    required this.contratoFirmado,
    required this.tienePagare,
    required this.pagareFirmado,
    required this.tieneIneCliente,
    required this.tieneComprobanteDomicilio,
    required this.numPagosRegistrados,
    required this.numIntentosCobro,
    required this.numNotificacionesMora,
    required this.numAvales,
    required this.avalesConDocumentos,
    required this.listoParaDemanda,
  });
  
  double get porcentajeCompletitud {
    int total = 10;
    int completados = 0;
    if (tieneContrato) completados++;
    if (contratoFirmado) completados++;
    if (tienePagare) completados++;
    if (pagareFirmado) completados++;
    if (tieneIneCliente) completados++;
    if (tieneComprobanteDomicilio) completados++;
    if (numIntentosCobro >= 3) completados++;
    if (numNotificacionesMora >= 2) completados++;
    if (numAvales > 0) completados++;
    if (avalesConDocumentos > 0) completados++;
    return (completados / total) * 100;
  }
}
