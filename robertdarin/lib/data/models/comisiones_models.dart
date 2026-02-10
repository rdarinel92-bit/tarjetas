/// Modelos para el sistema de comisiones de empleados
/// Referencia: Tabla comisiones_empleados y pagos_comisiones

/// Comisión generada para un empleado
class ComisionEmpleado {
  final String id;
  final String empleadoId;
  final String prestamoId;
  final double montoPrestamo;
  final double gananciaPrestamo;
  final double porcentajeComision;
  final double montoComision;
  final String tipoPago; // al_liquidar, proporcional, primer_pago
  final String estado; // pendiente, parcial, pagada, cancelada
  final double montoPagado;
  final DateTime fechaGeneracion;
  final DateTime? fechaPagoCompleto;
  final String? notas;
  final String? pagadoPor;
  final DateTime createdAt;
  final DateTime? updatedAt;

  ComisionEmpleado({
    required this.id,
    required this.empleadoId,
    required this.prestamoId,
    required this.montoPrestamo,
    required this.gananciaPrestamo,
    required this.porcentajeComision,
    required this.montoComision,
    required this.tipoPago,
    this.estado = 'pendiente',
    this.montoPagado = 0,
    required this.fechaGeneracion,
    this.fechaPagoCompleto,
    this.notas,
    this.pagadoPor,
    required this.createdAt,
    this.updatedAt,
  });

  /// Monto pendiente de pagar
  double get montoPendiente => montoComision - montoPagado;

  /// Porcentaje de avance de pago
  double get porcentajeAvance => montoComision > 0 ? (montoPagado / montoComision) * 100 : 0;

  /// Si está completamente pagada
  bool get pagadaCompleta => montoPagado >= montoComision;

  String get estadoColor {
    switch (estado) {
      case 'pendiente': return '#F59E0B';
      case 'parcial': return '#3B82F6';
      case 'pagada': return '#10B981';
      case 'cancelada': return '#EF4444';
      default: return '#6B7280';
    }
  }

  String get tipoPagoTexto {
    switch (tipoPago) {
      case 'al_liquidar': return 'Al liquidar préstamo';
      case 'proporcional': return 'Proporcional a pagos';
      case 'primer_pago': return 'En primer pago';
      default: return tipoPago;
    }
  }

  factory ComisionEmpleado.fromMap(Map<String, dynamic> map) {
    return ComisionEmpleado(
      id: map['id'] ?? '',
      empleadoId: map['empleado_id'] ?? '',
      prestamoId: map['prestamo_id'] ?? '',
      montoPrestamo: double.tryParse(map['monto_prestamo']?.toString() ?? '0') ?? 0,
      gananciaPrestamo: double.tryParse(map['ganancia_prestamo']?.toString() ?? '0') ?? 0,
      porcentajeComision: double.tryParse(map['porcentaje_comision']?.toString() ?? '0') ?? 0,
      montoComision: double.tryParse(map['monto_comision']?.toString() ?? '0') ?? 0,
      tipoPago: map['tipo_pago'] ?? 'al_liquidar',
      estado: map['estado'] ?? 'pendiente',
      montoPagado: double.tryParse(map['monto_pagado']?.toString() ?? '0') ?? 0,
      fechaGeneracion: DateTime.parse(map['fecha_generacion'] ?? DateTime.now().toIso8601String()),
      fechaPagoCompleto: map['fecha_pago_completo'] != null ? DateTime.parse(map['fecha_pago_completo']) : null,
      notas: map['notas'],
      pagadoPor: map['pagado_por'],
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
    );
  }

  Map<String, dynamic> toMapForInsert() => {
    'empleado_id': empleadoId,
    'prestamo_id': prestamoId,
    'monto_prestamo': montoPrestamo,
    'ganancia_prestamo': gananciaPrestamo,
    'porcentaje_comision': porcentajeComision,
    'monto_comision': montoComision,
    'tipo_pago': tipoPago,
    'estado': estado,
    'monto_pagado': montoPagado,
    'notas': notas,
  };
}

/// Pago realizado de una comisión
class PagoComision {
  final String id;
  final String comisionId;
  final double monto;
  final String? metodoPago;
  final String? referencia;
  final String? notas;
  final String? pagadoPor;
  final DateTime createdAt;

  PagoComision({
    required this.id,
    required this.comisionId,
    required this.monto,
    this.metodoPago,
    this.referencia,
    this.notas,
    this.pagadoPor,
    required this.createdAt,
  });

  factory PagoComision.fromMap(Map<String, dynamic> map) {
    return PagoComision(
      id: map['id'] ?? '',
      comisionId: map['comision_id'] ?? '',
      monto: double.tryParse(map['monto']?.toString() ?? '0') ?? 0,
      metodoPago: map['metodo_pago'],
      referencia: map['referencia'],
      notas: map['notas'],
      pagadoPor: map['pagado_por'],
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toMapForInsert() => {
    'comision_id': comisionId,
    'monto': monto,
    'metodo_pago': metodoPago,
    'referencia': referencia,
    'notas': notas,
    'pagado_por': pagadoPor,
  };
}

/// Registro de cobro (confirmación de pago)
class RegistroCobro {
  final String id;
  final String? prestamoId;
  final String? tandaId;
  final String? amortizacionId;
  final String clienteId;
  final double monto;
  final String? metodoPagoId;
  final String tipoMetodo; // efectivo, transferencia, tarjeta, qr
  final String estado; // pendiente, confirmado, rechazado
  final String? referenciaPago;
  final String? comprobanteUrl;
  final String? notaCliente;
  final String? notaOperador;
  final double? latitud;
  final double? longitud;
  final String? registradoPor;
  final String? confirmadoPor;
  final DateTime fechaRegistro;
  final DateTime? fechaConfirmacion;
  final DateTime createdAt;

  RegistroCobro({
    required this.id,
    this.prestamoId,
    this.tandaId,
    this.amortizacionId,
    required this.clienteId,
    required this.monto,
    this.metodoPagoId,
    this.tipoMetodo = 'efectivo',
    this.estado = 'pendiente',
    this.referenciaPago,
    this.comprobanteUrl,
    this.notaCliente,
    this.notaOperador,
    this.latitud,
    this.longitud,
    this.registradoPor,
    this.confirmadoPor,
    required this.fechaRegistro,
    this.fechaConfirmacion,
    required this.createdAt,
  });

  String get estadoColor {
    switch (estado) {
      case 'pendiente': return '#F59E0B';
      case 'confirmado': return '#10B981';
      case 'rechazado': return '#EF4444';
      default: return '#6B7280';
    }
  }

  String get tipoMetodoIcono {
    switch (tipoMetodo) {
      case 'efectivo': return '💵';
      case 'transferencia': return '🏦';
      case 'tarjeta': return '💳';
      case 'qr': return '📱';
      default: return '💰';
    }
  }

  factory RegistroCobro.fromMap(Map<String, dynamic> map) {
    return RegistroCobro(
      id: map['id'] ?? '',
      prestamoId: map['prestamo_id'],
      tandaId: map['tanda_id'],
      amortizacionId: map['amortizacion_id'],
      clienteId: map['cliente_id'] ?? '',
      monto: double.tryParse(map['monto']?.toString() ?? '0') ?? 0,
      metodoPagoId: map['metodo_pago_id'],
      tipoMetodo: map['tipo_metodo'] ?? 'efectivo',
      estado: map['estado'] ?? 'pendiente',
      referenciaPago: map['referencia_pago'],
      comprobanteUrl: map['comprobante_url'],
      notaCliente: map['nota_cliente'],
      notaOperador: map['nota_operador'],
      latitud: map['latitud'] != null ? double.tryParse(map['latitud'].toString()) : null,
      longitud: map['longitud'] != null ? double.tryParse(map['longitud'].toString()) : null,
      registradoPor: map['registrado_por'],
      confirmadoPor: map['confirmado_por'],
      fechaRegistro: DateTime.parse(map['fecha_registro'] ?? DateTime.now().toIso8601String()),
      fechaConfirmacion: map['fecha_confirmacion'] != null ? DateTime.parse(map['fecha_confirmacion']) : null,
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toMapForInsert() => {
    'prestamo_id': prestamoId,
    'tanda_id': tandaId,
    'amortizacion_id': amortizacionId,
    'cliente_id': clienteId,
    'monto': monto,
    'metodo_pago_id': metodoPagoId,
    'tipo_metodo': tipoMetodo,
    'referencia_pago': referenciaPago,
    'comprobante_url': comprobanteUrl,
    'nota_cliente': notaCliente,
    'latitud': latitud,
    'longitud': longitud,
    'registrado_por': registradoPor,
  };
}
