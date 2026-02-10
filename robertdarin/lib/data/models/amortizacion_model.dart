class AmortizacionModel {
  final String id;
  final String prestamoId;
  final int numeroCuota;
  final DateTime fechaVencimiento;
  final double monto;
  final double capital;
  final double interes;
  final String estado;
  final DateTime? fechaPago;

  AmortizacionModel({
    required this.id,
    required this.prestamoId,
    required this.numeroCuota,
    required this.fechaVencimiento,
    required this.monto,
    this.capital = 0,
    this.interes = 0,
    required this.estado,
    this.fechaPago,
  });

  factory AmortizacionModel.fromMap(Map<String, dynamic> map) {
    return AmortizacionModel(
      id: map['id'] ?? '',
      prestamoId: map['prestamo_id'] ?? '',
      numeroCuota: map['numero_cuota'] ?? 0,
      fechaVencimiento: DateTime.parse(map['fecha_vencimiento']),
      monto: (map['monto_cuota'] ?? map['monto'] ?? 0).toDouble(),
      capital: (map['monto_capital'] ?? map['capital'] ?? 0).toDouble(),
      interes: (map['monto_interes'] ?? map['interes'] ?? 0).toDouble(),
      estado: map['estado'] ?? 'pendiente',
      fechaPago: map['fecha_pago'] != null ? DateTime.parse(map['fecha_pago']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'prestamo_id': prestamoId,
      'numero_cuota': numeroCuota,
      'fecha_vencimiento': fechaVencimiento.toIso8601String(),
      'monto_cuota': monto,
      'monto_capital': capital,
      'monto_interes': interes,
      'estado': estado,
      'fecha_pago': fechaPago?.toIso8601String(),
    };
  }

  Map<String, dynamic> toMapForInsert() {
    return {
      'prestamo_id': prestamoId,
      'numero_cuota': numeroCuota,
      'fecha_vencimiento': fechaVencimiento.toIso8601String(),
      'monto_cuota': monto,
      'monto_capital': capital,
      'monto_interes': interes,
      'estado': estado,
      'fecha_pago': fechaPago?.toIso8601String(),
    };
  }

  AmortizacionModel copyWith({
    String? id,
    String? prestamoId,
    int? numeroCuota,
    DateTime? fechaVencimiento,
    double? monto,
    double? capital,
    double? interes,
    String? estado,
    DateTime? fechaPago,
  }) {
    return AmortizacionModel(
      id: id ?? this.id,
      prestamoId: prestamoId ?? this.prestamoId,
      numeroCuota: numeroCuota ?? this.numeroCuota,
      fechaVencimiento: fechaVencimiento ?? this.fechaVencimiento,
      monto: monto ?? this.monto,
      capital: capital ?? this.capital,
      interes: interes ?? this.interes,
      estado: estado ?? this.estado,
      fechaPago: fechaPago ?? this.fechaPago,
    );
  }

  /// Alias para compatibilidad
  double get montoCuota => monto;
}
