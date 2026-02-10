/// ============================================================
/// MODELO DE MÉTODOS DE PAGO - Robert Darin Fintech V9.0
/// Datos bancarios, QR, enlaces de pago
/// ============================================================

class MetodoPagoModel {
  final String id;
  final String tipo; // efectivo, transferencia, tarjeta, oxxo, paypal
  final String nombre; // "BBVA Empresarial", "Santander Personal", etc.
  final String? banco;
  final String? numeroCuenta;
  final String? clabe;
  final String? tarjeta; // Últimos 4 dígitos
  final String? titular;
  final String? qrUrl; // URL de imagen QR para pago
  final String? enlacePago; // Link de pago (PayPal, Mercado Pago, etc.)
  final String? instrucciones;
  final bool activo;
  final bool principal; // Método principal/default
  final int orden;
  final DateTime createdAt;
  final DateTime? updatedAt;

  MetodoPagoModel({
    required this.id,
    required this.tipo,
    required this.nombre,
    this.banco,
    this.numeroCuenta,
    this.clabe,
    this.tarjeta,
    this.titular,
    this.qrUrl,
    this.enlacePago,
    this.instrucciones,
    this.activo = true,
    this.principal = false,
    this.orden = 0,
    required this.createdAt,
    this.updatedAt,
  });

  factory MetodoPagoModel.fromMap(Map<String, dynamic> map) {
    return MetodoPagoModel(
      id: map['id'],
      tipo: map['tipo'] ?? 'efectivo',
      nombre: map['nombre'] ?? '',
      banco: map['banco'],
      numeroCuenta: map['numero_cuenta'],
      clabe: map['clabe'],
      tarjeta: map['tarjeta'],
      titular: map['titular'],
      qrUrl: map['qr_url'],
      enlacePago: map['enlace_pago'],
      instrucciones: map['instrucciones'],
      activo: map['activo'] ?? true,
      principal: map['principal'] ?? false,
      orden: map['orden'] ?? 0,
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: map['updated_at'] != null 
          ? DateTime.parse(map['updated_at']) 
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tipo': tipo,
      'nombre': nombre,
      'banco': banco,
      'numero_cuenta': numeroCuenta,
      'clabe': clabe,
      'tarjeta': tarjeta,
      'titular': titular,
      'qr_url': qrUrl,
      'enlace_pago': enlacePago,
      'instrucciones': instrucciones,
      'activo': activo,
      'principal': principal,
      'orden': orden,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> toMapForInsert() {
    final map = toMap();
    map.remove('id');
    map.remove('created_at');
    map.remove('updated_at');
    return map;
  }

  /// Obtiene icono según tipo
  String get icono {
    switch (tipo) {
      case 'efectivo':
        return '💵';
      case 'transferencia':
        return '🏦';
      case 'tarjeta':
        return '💳';
      case 'oxxo':
        return '🏪';
      case 'paypal':
        return '🅿️';
      case 'mercadopago':
        return '💙';
      default:
        return '💰';
    }
  }

  /// Datos formateados para mostrar
  String get datosFormateados {
    if (tipo == 'transferencia') {
      return '''
Banco: $banco
Titular: $titular
CLABE: $clabe
${numeroCuenta != null ? 'Cuenta: $numeroCuenta' : ''}
'''.trim();
    } else if (tipo == 'tarjeta') {
      return 'Tarjeta: •••• $tarjeta';
    }
    return instrucciones ?? '';
  }

  MetodoPagoModel copyWith({
    String? id,
    String? tipo,
    String? nombre,
    String? banco,
    String? numeroCuenta,
    String? clabe,
    String? tarjeta,
    String? titular,
    String? qrUrl,
    String? enlacePago,
    String? instrucciones,
    bool? activo,
    bool? principal,
    int? orden,
  }) {
    return MetodoPagoModel(
      id: id ?? this.id,
      tipo: tipo ?? this.tipo,
      nombre: nombre ?? this.nombre,
      banco: banco ?? this.banco,
      numeroCuenta: numeroCuenta ?? this.numeroCuenta,
      clabe: clabe ?? this.clabe,
      tarjeta: tarjeta ?? this.tarjeta,
      titular: titular ?? this.titular,
      qrUrl: qrUrl ?? this.qrUrl,
      enlacePago: enlacePago ?? this.enlacePago,
      instrucciones: instrucciones ?? this.instrucciones,
      activo: activo ?? this.activo,
      principal: principal ?? this.principal,
      orden: orden ?? this.orden,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}

/// Modelo para registro de cobro/pago con confirmación
class RegistroCobro {
  final String id;
  final String? prestamoId;
  final String? tandaId;
  final String? amortizacionId;
  final String clienteId;
  final double monto;
  final String metodoPagoId;
  final String tipoMetodo; // efectivo, transferencia, etc.
  final String estado; // pendiente, confirmado, rechazado
  final String? referenciaPago; // Número de referencia/transacción
  final String? comprobanteUrl; // Foto del comprobante
  final String? notaCliente;
  final String? notaOperador;
  final double? latitud;
  final double? longitud;
  final String? registradoPor; // Usuario que registró
  final String? confirmadoPor; // Usuario que confirmó
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
    required this.metodoPagoId,
    required this.tipoMetodo,
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

  factory RegistroCobro.fromMap(Map<String, dynamic> map) {
    return RegistroCobro(
      id: map['id'],
      prestamoId: map['prestamo_id'],
      tandaId: map['tanda_id'],
      amortizacionId: map['amortizacion_id'],
      clienteId: map['cliente_id'],
      monto: (map['monto'] as num).toDouble(),
      metodoPagoId: map['metodo_pago_id'],
      tipoMetodo: map['tipo_metodo'] ?? 'efectivo',
      estado: map['estado'] ?? 'pendiente',
      referenciaPago: map['referencia_pago'],
      comprobanteUrl: map['comprobante_url'],
      notaCliente: map['nota_cliente'],
      notaOperador: map['nota_operador'],
      latitud: map['latitud'] != null ? (map['latitud'] as num).toDouble() : null,
      longitud: map['longitud'] != null ? (map['longitud'] as num).toDouble() : null,
      registradoPor: map['registrado_por'],
      confirmadoPor: map['confirmado_por'],
      fechaRegistro: DateTime.parse(map['fecha_registro']),
      fechaConfirmacion: map['fecha_confirmacion'] != null 
          ? DateTime.parse(map['fecha_confirmacion']) 
          : null,
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'prestamo_id': prestamoId,
      'tanda_id': tandaId,
      'amortizacion_id': amortizacionId,
      'cliente_id': clienteId,
      'monto': monto,
      'metodo_pago_id': metodoPagoId,
      'tipo_metodo': tipoMetodo,
      'estado': estado,
      'referencia_pago': referenciaPago,
      'comprobante_url': comprobanteUrl,
      'nota_cliente': notaCliente,
      'nota_operador': notaOperador,
      'latitud': latitud,
      'longitud': longitud,
      'registrado_por': registradoPor,
      'confirmado_por': confirmadoPor,
      'fecha_registro': fechaRegistro.toIso8601String(),
      'fecha_confirmacion': fechaConfirmacion?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  bool get estaPendiente => estado == 'pendiente';
  bool get estaConfirmado => estado == 'confirmado';
  bool get estaRechazado => estado == 'rechazado';

  String get estadoIcono {
    switch (estado) {
      case 'confirmado':
        return '✅';
      case 'rechazado':
        return '❌';
      default:
        return '⏳';
    }
  }
}
