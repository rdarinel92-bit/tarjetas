/// Modelos para el sistema de auditoría legal y evidencias
/// Sección 29 del schema: SISTEMA DE AUDITORÍA LEGAL Y EVIDENCIAS PARA JUICIOS

/// Intento de cobro documentado (evidencia para juicio)
class IntentoCobro {
  final String id;
  final String prestamoId;
  final String clienteId;
  final String? cobradorId;
  final String tipo; // llamada, visita, mensaje, notificacion, carta, email
  final String resultado; // contestado, no_contestado, promesa_pago, negado, buzon, numero_equivocado
  final String? notas;
  final double? latitud;
  final double? longitud;
  final int? duracionLlamada;
  final String? grabacionUrl;
  final DateTime fecha;
  final String hashRegistro;
  final DateTime createdAt;

  IntentoCobro({
    required this.id,
    required this.prestamoId,
    required this.clienteId,
    this.cobradorId,
    required this.tipo,
    required this.resultado,
    this.notas,
    this.latitud,
    this.longitud,
    this.duracionLlamada,
    this.grabacionUrl,
    required this.fecha,
    required this.hashRegistro,
    required this.createdAt,
  });

  String get tipoIcono {
    switch (tipo) {
      case 'llamada': return '📞';
      case 'visita': return '🚗';
      case 'mensaje': return '💬';
      case 'notificacion': return '🔔';
      case 'carta': return '✉️';
      case 'email': return '📧';
      default: return '📋';
    }
  }

  String get resultadoColor {
    switch (resultado) {
      case 'contestado': return '#10B981';
      case 'promesa_pago': return '#3B82F6';
      case 'no_contestado': return '#F59E0B';
      case 'negado': return '#EF4444';
      case 'buzon': return '#6B7280';
      default: return '#6B7280';
    }
  }

  factory IntentoCobro.fromMap(Map<String, dynamic> map) {
    return IntentoCobro(
      id: map['id'] ?? '',
      prestamoId: map['prestamo_id'] ?? '',
      clienteId: map['cliente_id'] ?? '',
      cobradorId: map['cobrador_id'],
      tipo: map['tipo'] ?? '',
      resultado: map['resultado'] ?? '',
      notas: map['notas'],
      latitud: map['latitud'] != null ? double.tryParse(map['latitud'].toString()) : null,
      longitud: map['longitud'] != null ? double.tryParse(map['longitud'].toString()) : null,
      duracionLlamada: map['duracion_llamada'],
      grabacionUrl: map['grabacion_url'],
      fecha: DateTime.parse(map['fecha'] ?? DateTime.now().toIso8601String()),
      hashRegistro: map['hash_registro'] ?? '',
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toMapForInsert() => {
    'prestamo_id': prestamoId,
    'cliente_id': clienteId,
    'cobrador_id': cobradorId,
    'tipo': tipo,
    'resultado': resultado,
    'notas': notas,
    'latitud': latitud,
    'longitud': longitud,
    'duracion_llamada': duracionLlamada,
    'grabacion_url': grabacionUrl,
    'fecha': fecha.toIso8601String(),
    'hash_registro': hashRegistro,
  };
}

/// Expediente legal generado
class ExpedienteLegal {
  final String id;
  final String prestamoId;
  final String clienteId;
  final DateTime fechaGeneracion;
  final String hashExpediente;
  final Map<String, dynamic>? estadoCuenta;
  final int numComunicaciones;
  final int numPagos;
  final double? totalAdeudado;
  final int? diasMora;
  final String estado; // generado, enviado_abogado, en_demanda, sentencia
  final String? abogadoAsignado;
  final String? numeroExpedienteJudicial;
  final String? juzgado;
  final String? notasLegales;
  final DateTime createdAt;
  final DateTime? updatedAt;

  ExpedienteLegal({
    required this.id,
    required this.prestamoId,
    required this.clienteId,
    required this.fechaGeneracion,
    required this.hashExpediente,
    this.estadoCuenta,
    this.numComunicaciones = 0,
    this.numPagos = 0,
    this.totalAdeudado,
    this.diasMora,
    this.estado = 'generado',
    this.abogadoAsignado,
    this.numeroExpedienteJudicial,
    this.juzgado,
    this.notasLegales,
    required this.createdAt,
    this.updatedAt,
  });

  String get estadoColor {
    switch (estado) {
      case 'generado': return '#6B7280';
      case 'enviado_abogado': return '#F59E0B';
      case 'en_demanda': return '#EF4444';
      case 'sentencia': return '#8B5CF6';
      default: return '#6B7280';
    }
  }

  factory ExpedienteLegal.fromMap(Map<String, dynamic> map) {
    return ExpedienteLegal(
      id: map['id'] ?? '',
      prestamoId: map['prestamo_id'] ?? '',
      clienteId: map['cliente_id'] ?? '',
      fechaGeneracion: DateTime.parse(map['fecha_generacion'] ?? DateTime.now().toIso8601String()),
      hashExpediente: map['hash_expediente'] ?? '',
      estadoCuenta: map['estado_cuenta'],
      numComunicaciones: map['num_comunicaciones'] ?? 0,
      numPagos: map['num_pagos'] ?? 0,
      totalAdeudado: map['total_adeudado'] != null ? double.tryParse(map['total_adeudado'].toString()) : null,
      diasMora: map['dias_mora'],
      estado: map['estado'] ?? 'generado',
      abogadoAsignado: map['abogado_asignado'],
      numeroExpedienteJudicial: map['numero_expediente_judicial'],
      juzgado: map['juzgado'],
      notasLegales: map['notas_legales'],
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
    );
  }

  Map<String, dynamic> toMapForInsert() => {
    'prestamo_id': prestamoId,
    'cliente_id': clienteId,
    'hash_expediente': hashExpediente,
    'estado_cuenta': estadoCuenta,
    'total_adeudado': totalAdeudado,
    'dias_mora': diasMora,
    'estado': estado,
    'abogado_asignado': abogadoAsignado,
  };
}

/// Promesa de pago registrada
class PromesaPago {
  final String id;
  final String prestamoId;
  final String clienteId;
  final String? intentoCobroId;
  final double montoPrometido;
  final DateTime fechaPromesa;
  final DateTime fechaCompromiso;
  final bool cumplida;
  final DateTime? fechaCumplimiento;
  final String? notas;
  final String? grabacionUrl;
  final String? hashPromesa;
  final DateTime createdAt;

  PromesaPago({
    required this.id,
    required this.prestamoId,
    required this.clienteId,
    this.intentoCobroId,
    required this.montoPrometido,
    required this.fechaPromesa,
    required this.fechaCompromiso,
    this.cumplida = false,
    this.fechaCumplimiento,
    this.notas,
    this.grabacionUrl,
    this.hashPromesa,
    required this.createdAt,
  });

  /// Si la promesa está vencida sin cumplir
  bool get vencida => !cumplida && DateTime.now().isAfter(fechaCompromiso);

  /// Días para cumplir (negativo si ya venció)
  int get diasParaCumplir => fechaCompromiso.difference(DateTime.now()).inDays;

  factory PromesaPago.fromMap(Map<String, dynamic> map) {
    return PromesaPago(
      id: map['id'] ?? '',
      prestamoId: map['prestamo_id'] ?? '',
      clienteId: map['cliente_id'] ?? '',
      intentoCobroId: map['intento_cobro_id'],
      montoPrometido: double.tryParse(map['monto_prometido']?.toString() ?? '0') ?? 0,
      fechaPromesa: DateTime.parse(map['fecha_promesa'] ?? DateTime.now().toIso8601String()),
      fechaCompromiso: DateTime.parse(map['fecha_compromiso'] ?? DateTime.now().toIso8601String()),
      cumplida: map['cumplida'] ?? false,
      fechaCumplimiento: map['fecha_cumplimiento'] != null ? DateTime.parse(map['fecha_cumplimiento']) : null,
      notas: map['notas'],
      grabacionUrl: map['grabacion_url'],
      hashPromesa: map['hash_promesa'],
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toMapForInsert() => {
    'prestamo_id': prestamoId,
    'cliente_id': clienteId,
    'intento_cobro_id': intentoCobroId,
    'monto_prometido': montoPrometido,
    'fecha_promesa': fechaPromesa.toIso8601String().split('T').first,
    'fecha_compromiso': fechaCompromiso.toIso8601String().split('T').first,
    'notas': notas,
    'grabacion_url': grabacionUrl,
    'hash_promesa': hashPromesa,
  };
}

/// Seguimiento de proceso judicial
class SeguimientoJudicial {
  final String id;
  final String expedienteId;
  final DateTime fecha;
  final String etapa; // demanda_presentada, admision, emplazamiento, contestacion, pruebas, alegatos, sentencia, ejecucion
  final String? descripcion;
  final String? documentoUrl;
  final String? proximoPaso;
  final DateTime? fechaProximaAccion;
  final String? responsable;
  final DateTime createdAt;

  SeguimientoJudicial({
    required this.id,
    required this.expedienteId,
    required this.fecha,
    required this.etapa,
    this.descripcion,
    this.documentoUrl,
    this.proximoPaso,
    this.fechaProximaAccion,
    this.responsable,
    required this.createdAt,
  });

  String get etapaTexto {
    switch (etapa) {
      case 'demanda_presentada': return 'Demanda Presentada';
      case 'admision': return 'Admisión';
      case 'emplazamiento': return 'Emplazamiento';
      case 'contestacion': return 'Contestación';
      case 'pruebas': return 'Pruebas';
      case 'alegatos': return 'Alegatos';
      case 'sentencia': return 'Sentencia';
      case 'ejecucion': return 'Ejecución';
      default: return etapa;
    }
  }

  factory SeguimientoJudicial.fromMap(Map<String, dynamic> map) {
    return SeguimientoJudicial(
      id: map['id'] ?? '',
      expedienteId: map['expediente_id'] ?? '',
      fecha: DateTime.parse(map['fecha'] ?? DateTime.now().toIso8601String()),
      etapa: map['etapa'] ?? '',
      descripcion: map['descripcion'],
      documentoUrl: map['documento_url'],
      proximoPaso: map['proximo_paso'],
      fechaProximaAccion: map['fecha_proxima_accion'] != null ? DateTime.parse(map['fecha_proxima_accion']) : null,
      responsable: map['responsable'],
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toMapForInsert() => {
    'expediente_id': expedienteId,
    'fecha': fecha.toIso8601String(),
    'etapa': etapa,
    'descripcion': descripcion,
    'documento_url': documentoUrl,
    'proximo_paso': proximoPaso,
    'fecha_proxima_accion': fechaProximaAccion?.toIso8601String().split('T').first,
    'responsable': responsable,
  };
}
