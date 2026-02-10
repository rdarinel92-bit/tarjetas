class PagoModel {
  final String id;
  final String prestamoId;
  final double monto;
  final DateTime fechaPago;
  final String nota;
  final double? latitud;
  final double? longitud;
  final String comprobanteUrl;
  final DateTime createdAt;
  // V10.30: Campos adicionales para multi-tenant y métodos de pago
  final String? negocioId;
  final String? clienteId;
  final String? tandaId;
  final String? metodoPago;
  final String? estado;

  PagoModel({
    required this.id,
    required this.prestamoId,
    required this.monto,
    required this.fechaPago,
    required this.nota,
    this.latitud,
    this.longitud,
    required this.comprobanteUrl,
    required this.createdAt,
    this.negocioId,
    this.clienteId,
    this.tandaId,
    this.metodoPago,
    this.estado,
  });

  factory PagoModel.fromMap(Map<String, dynamic> map) {
    return PagoModel(
      id: map['id'] ?? '',
      prestamoId: map['prestamo_id'] ?? '',
      monto: (map['monto'] as num?)?.toDouble() ?? 0.0,
      fechaPago: DateTime.parse(map['fecha_pago'] ?? DateTime.now().toIso8601String()),
      nota: map['nota'] ?? '',
      latitud: map['latitud'] != null ? (map['latitud'] as num).toDouble() : null,
      longitud: map['longitud'] != null ? (map['longitud'] as num).toDouble() : null,
      comprobanteUrl: map['comprobante_url'] ?? '',
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
      negocioId: map['negocio_id'],
      clienteId: map['cliente_id'],
      tandaId: map['tanda_id'],
      metodoPago: map['metodo_pago'],
      estado: map['estado'],
    );
  }

  /// Para UPDATE (incluye id)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'prestamo_id': prestamoId,
      'monto': monto,
      'fecha_pago': fechaPago.toIso8601String(),
      'nota': nota,
      'latitud': latitud,
      'longitud': longitud,
      'comprobante_url': comprobanteUrl,
      if (negocioId != null) 'negocio_id': negocioId,
      if (clienteId != null) 'cliente_id': clienteId,
      if (tandaId != null) 'tanda_id': tandaId,
      if (metodoPago != null) 'metodo_pago': metodoPago,
      if (estado != null) 'estado': estado,
    };
  }

  /// Para INSERT (sin id ni created_at, Supabase los genera)
  Map<String, dynamic> toMapForInsert() {
    return {
      'prestamo_id': prestamoId,
      'monto': monto,
      'fecha_pago': fechaPago.toIso8601String(),
      'nota': nota,
      'latitud': latitud,
      'longitud': longitud,
      'comprobante_url': comprobanteUrl,
      if (negocioId != null) 'negocio_id': negocioId,
      if (clienteId != null) 'cliente_id': clienteId,
      if (tandaId != null) 'tanda_id': tandaId,
      if (metodoPago != null) 'metodo_pago': metodoPago,
      if (estado != null) 'estado': estado,
    };
  }
}
