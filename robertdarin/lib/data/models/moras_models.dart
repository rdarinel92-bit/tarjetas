/// Modelos para el sistema de moras y penalizaciones
/// Sección 33 del schema: SISTEMA DE MORAS Y PENALIZACIONES (V10.6)

/// Configuración de moras por negocio
class ConfiguracionMoras {
  final String id;
  final String? negocioId;
  
  // Configuración para préstamos
  final double prestamosMoraDiaria;
  final double prestamosMoraMaxima;
  final int prestamosDiasGracia;
  final bool prestamosAplicarAutomatico;
  
  // Configuración para tandas
  final double tandasMoraDiaria;
  final double tandasMoraMaxima;
  final int tandasDiasGracia;
  final bool tandasAplicarAutomatico;
  
  // Notificaciones automáticas
  final int notificarDiasAntes;
  final bool notificarRecordatorioDiario;
  final bool notificarAlAval;
  
  // Escalamiento de notificaciones
  final int nivel1Dias;
  final int nivel2Dias;
  final int nivel3Dias;
  final int nivel4Dias;
  
  // Acciones automáticas
  final int bloquearClienteDias;
  final int enviarALegalDias;
  
  final DateTime createdAt;
  final DateTime? updatedAt;

  ConfiguracionMoras({
    required this.id,
    this.negocioId,
    this.prestamosMoraDiaria = 1.0,
    this.prestamosMoraMaxima = 30.0,
    this.prestamosDiasGracia = 0,
    this.prestamosAplicarAutomatico = true,
    this.tandasMoraDiaria = 2.0,
    this.tandasMoraMaxima = 50.0,
    this.tandasDiasGracia = 1,
    this.tandasAplicarAutomatico = true,
    this.notificarDiasAntes = 3,
    this.notificarRecordatorioDiario = true,
    this.notificarAlAval = true,
    this.nivel1Dias = 1,
    this.nivel2Dias = 7,
    this.nivel3Dias = 15,
    this.nivel4Dias = 30,
    this.bloquearClienteDias = 60,
    this.enviarALegalDias = 90,
    required this.createdAt,
    this.updatedAt,
  });

  factory ConfiguracionMoras.fromMap(Map<String, dynamic> map) {
    return ConfiguracionMoras(
      id: map['id'] ?? '',
      negocioId: map['negocio_id'],
      prestamosMoraDiaria: double.tryParse(map['prestamos_mora_diaria']?.toString() ?? '1.0') ?? 1.0,
      prestamosMoraMaxima: double.tryParse(map['prestamos_mora_maxima']?.toString() ?? '30.0') ?? 30.0,
      prestamosDiasGracia: map['prestamos_dias_gracia'] ?? 0,
      prestamosAplicarAutomatico: map['prestamos_aplicar_automatico'] ?? true,
      tandasMoraDiaria: double.tryParse(map['tandas_mora_diaria']?.toString() ?? '2.0') ?? 2.0,
      tandasMoraMaxima: double.tryParse(map['tandas_mora_maxima']?.toString() ?? '50.0') ?? 50.0,
      tandasDiasGracia: map['tandas_dias_gracia'] ?? 1,
      tandasAplicarAutomatico: map['tandas_aplicar_automatico'] ?? true,
      notificarDiasAntes: map['notificar_dias_antes'] ?? 3,
      notificarRecordatorioDiario: map['notificar_recordatorio_diario'] ?? true,
      notificarAlAval: map['notificar_al_aval'] ?? true,
      nivel1Dias: map['nivel_1_dias'] ?? 1,
      nivel2Dias: map['nivel_2_dias'] ?? 7,
      nivel3Dias: map['nivel_3_dias'] ?? 15,
      nivel4Dias: map['nivel_4_dias'] ?? 30,
      bloquearClienteDias: map['bloquear_cliente_dias'] ?? 60,
      enviarALegalDias: map['enviar_a_legal_dias'] ?? 90,
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'negocio_id': negocioId,
    'prestamos_mora_diaria': prestamosMoraDiaria,
    'prestamos_mora_maxima': prestamosMoraMaxima,
    'prestamos_dias_gracia': prestamosDiasGracia,
    'prestamos_aplicar_automatico': prestamosAplicarAutomatico,
    'tandas_mora_diaria': tandasMoraDiaria,
    'tandas_mora_maxima': tandasMoraMaxima,
    'tandas_dias_gracia': tandasDiasGracia,
    'tandas_aplicar_automatico': tandasAplicarAutomatico,
    'notificar_dias_antes': notificarDiasAntes,
    'notificar_recordatorio_diario': notificarRecordatorioDiario,
    'notificar_al_aval': notificarAlAval,
    'nivel_1_dias': nivel1Dias,
    'nivel_2_dias': nivel2Dias,
    'nivel_3_dias': nivel3Dias,
    'nivel_4_dias': nivel4Dias,
    'bloquear_cliente_dias': bloquearClienteDias,
    'enviar_a_legal_dias': enviarALegalDias,
  };
}

/// Mora aplicada a un préstamo
class MoraPrestamo {
  final String id;
  final String prestamoId;
  final String amortizacionId;
  final int diasMora;
  final double montoCuotaOriginal;
  final double porcentajeMoraAplicado;
  final double montoMora;
  final double montoTotalConMora;
  final String estado; // pendiente, pagada, condonada, en_legal
  final String? condonadoPor;
  final String? motivoCondonacion;
  final DateTime? fechaCondonacion;
  final double montoMoraPagado;
  final DateTime? fechaPagoMora;
  final bool generadoAutomatico;
  final DateTime createdAt;
  final DateTime? updatedAt;

  MoraPrestamo({
    required this.id,
    required this.prestamoId,
    required this.amortizacionId,
    required this.diasMora,
    required this.montoCuotaOriginal,
    required this.porcentajeMoraAplicado,
    required this.montoMora,
    required this.montoTotalConMora,
    this.estado = 'pendiente',
    this.condonadoPor,
    this.motivoCondonacion,
    this.fechaCondonacion,
    this.montoMoraPagado = 0,
    this.fechaPagoMora,
    this.generadoAutomatico = true,
    required this.createdAt,
    this.updatedAt,
  });

  /// Monto pendiente de mora
  double get moraPendiente => montoMora - montoMoraPagado;

  /// Si está pagada completamente
  bool get pagadaCompleta => montoMoraPagado >= montoMora;

  String get estadoColor {
    switch (estado) {
      case 'pendiente': return '#F59E0B';
      case 'pagada': return '#10B981';
      case 'condonada': return '#3B82F6';
      case 'en_legal': return '#EF4444';
      default: return '#6B7280';
    }
  }

  factory MoraPrestamo.fromMap(Map<String, dynamic> map) {
    return MoraPrestamo(
      id: map['id'] ?? '',
      prestamoId: map['prestamo_id'] ?? '',
      amortizacionId: map['amortizacion_id'] ?? '',
      diasMora: map['dias_mora'] ?? 0,
      montoCuotaOriginal: double.tryParse(map['monto_cuota_original']?.toString() ?? '0') ?? 0,
      porcentajeMoraAplicado: double.tryParse(map['porcentaje_mora_aplicado']?.toString() ?? '0') ?? 0,
      montoMora: double.tryParse(map['monto_mora']?.toString() ?? '0') ?? 0,
      montoTotalConMora: double.tryParse(map['monto_total_con_mora']?.toString() ?? '0') ?? 0,
      estado: map['estado'] ?? 'pendiente',
      condonadoPor: map['condonado_por'],
      motivoCondonacion: map['motivo_condonacion'],
      fechaCondonacion: map['fecha_condonacion'] != null ? DateTime.parse(map['fecha_condonacion']) : null,
      montoMoraPagado: double.tryParse(map['monto_mora_pagado']?.toString() ?? '0') ?? 0,
      fechaPagoMora: map['fecha_pago_mora'] != null ? DateTime.parse(map['fecha_pago_mora']) : null,
      generadoAutomatico: map['generado_automatico'] ?? true,
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
    );
  }

  Map<String, dynamic> toMapForInsert() => {
    'prestamo_id': prestamoId,
    'amortizacion_id': amortizacionId,
    'dias_mora': diasMora,
    'monto_cuota_original': montoCuotaOriginal,
    'porcentaje_mora_aplicado': porcentajeMoraAplicado,
    'monto_mora': montoMora,
    'monto_total_con_mora': montoTotalConMora,
    'estado': estado,
    'generado_automatico': generadoAutomatico,
  };
}

/// Notificación de mora enviada al cliente
class NotificacionMoraCliente {
  final String id;
  final String clienteId;
  final String tipoDeuda; // prestamo, tanda
  final String? prestamoId;
  final String? tandaId;
  final String nivelMora; // recordatorio, leve, seria, grave, critica, legal
  final String titulo;
  final String mensaje;
  final int? diasMora;
  final double? montoPendiente;
  final double? montoMora;
  final double? montoTotal;
  final String canal; // app, push, sms, email, whatsapp
  final bool enviado;
  final bool leido;
  final DateTime? fechaLectura;
  final bool enviadoAAval;
  final String? avalId;
  final DateTime createdAt;

  NotificacionMoraCliente({
    required this.id,
    required this.clienteId,
    required this.tipoDeuda,
    this.prestamoId,
    this.tandaId,
    required this.nivelMora,
    required this.titulo,
    required this.mensaje,
    this.diasMora,
    this.montoPendiente,
    this.montoMora,
    this.montoTotal,
    this.canal = 'app',
    this.enviado = true,
    this.leido = false,
    this.fechaLectura,
    this.enviadoAAval = false,
    this.avalId,
    required this.createdAt,
  });

  String get nivelColor {
    switch (nivelMora) {
      case 'recordatorio': return '#3B82F6';
      case 'leve': return '#F59E0B';
      case 'seria': return '#F97316';
      case 'grave': return '#EF4444';
      case 'critica': return '#DC2626';
      case 'legal': return '#7C3AED';
      default: return '#6B7280';
    }
  }

  String get nivelIcono {
    switch (nivelMora) {
      case 'recordatorio': return '🔔';
      case 'leve': return '⚠️';
      case 'seria': return '⚠️';
      case 'grave': return '🚨';
      case 'critica': return '❗';
      case 'legal': return '⚖️';
      default: return '📋';
    }
  }

  factory NotificacionMoraCliente.fromMap(Map<String, dynamic> map) {
    return NotificacionMoraCliente(
      id: map['id'] ?? '',
      clienteId: map['cliente_id'] ?? '',
      tipoDeuda: map['tipo_deuda'] ?? 'prestamo',
      prestamoId: map['prestamo_id'],
      tandaId: map['tanda_id'],
      nivelMora: map['nivel_mora'] ?? 'leve',
      titulo: map['titulo'] ?? '',
      mensaje: map['mensaje'] ?? '',
      diasMora: map['dias_mora'],
      montoPendiente: map['monto_pendiente'] != null ? double.tryParse(map['monto_pendiente'].toString()) : null,
      montoMora: map['monto_mora'] != null ? double.tryParse(map['monto_mora'].toString()) : null,
      montoTotal: map['monto_total'] != null ? double.tryParse(map['monto_total'].toString()) : null,
      canal: map['canal'] ?? 'app',
      enviado: map['enviado'] ?? true,
      leido: map['leido'] ?? false,
      fechaLectura: map['fecha_lectura'] != null ? DateTime.parse(map['fecha_lectura']) : null,
      enviadoAAval: map['enviado_a_aval'] ?? false,
      avalId: map['aval_id'],
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toMapForInsert() => {
    'cliente_id': clienteId,
    'tipo_deuda': tipoDeuda,
    'prestamo_id': prestamoId,
    'tanda_id': tandaId,
    'nivel_mora': nivelMora,
    'titulo': titulo,
    'mensaje': mensaje,
    'dias_mora': diasMora,
    'monto_pendiente': montoPendiente,
    'monto_mora': montoMora,
    'monto_total': montoTotal,
    'canal': canal,
    'enviado_a_aval': enviadoAAval,
    'aval_id': avalId,
  };
}

/// Cliente bloqueado por mora excesiva
class ClienteBloqueadoMora {
  final String id;
  final String clienteId;
  final String motivo;
  final int diasMoraMaximo;
  final double montoTotalAdeudado;
  final List<String>? prestamosEnMora;
  final List<String>? tandasEnMora;
  final bool activo;
  final DateTime? fechaDesbloqueo;
  final String? desbloqueadoPor;
  final String? motivoDesbloqueo;
  final String? bloqueadoPor;
  final DateTime createdAt;

  ClienteBloqueadoMora({
    required this.id,
    required this.clienteId,
    required this.motivo,
    required this.diasMoraMaximo,
    required this.montoTotalAdeudado,
    this.prestamosEnMora,
    this.tandasEnMora,
    this.activo = true,
    this.fechaDesbloqueo,
    this.desbloqueadoPor,
    this.motivoDesbloqueo,
    this.bloqueadoPor,
    required this.createdAt,
  });

  /// Total de deudas en mora
  int get totalDeudasEnMora => 
    (prestamosEnMora?.length ?? 0) + (tandasEnMora?.length ?? 0);

  factory ClienteBloqueadoMora.fromMap(Map<String, dynamic> map) {
    return ClienteBloqueadoMora(
      id: map['id'] ?? '',
      clienteId: map['cliente_id'] ?? '',
      motivo: map['motivo'] ?? '',
      diasMoraMaximo: map['dias_mora_maximo'] ?? 0,
      montoTotalAdeudado: double.tryParse(map['monto_total_adeudado']?.toString() ?? '0') ?? 0,
      prestamosEnMora: map['prestamos_en_mora'] != null 
          ? List<String>.from(map['prestamos_en_mora']) 
          : null,
      tandasEnMora: map['tandas_en_mora'] != null 
          ? List<String>.from(map['tandas_en_mora']) 
          : null,
      activo: map['activo'] ?? true,
      fechaDesbloqueo: map['fecha_desbloqueo'] != null ? DateTime.parse(map['fecha_desbloqueo']) : null,
      desbloqueadoPor: map['desbloqueado_por'],
      motivoDesbloqueo: map['motivo_desbloqueo'],
      bloqueadoPor: map['bloqueado_por'],
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toMapForInsert() => {
    'cliente_id': clienteId,
    'motivo': motivo,
    'dias_mora_maximo': diasMoraMaximo,
    'monto_total_adeudado': montoTotalAdeudado,
    'prestamos_en_mora': prestamosEnMora,
    'tandas_en_mora': tandasEnMora,
    'bloqueado_por': bloqueadoPor,
  };
}
