class TandaParticipanteModel {
  final String id;
  final String tandaId;
  final String clienteId;
  final String? clienteNombre; // Para joins
  final int numeroTurno;
  final bool haPagadoCuotaActual;
  final bool haRecibidoBolsa;
  final DateTime? fechaRecepcionBolsa;

  TandaParticipanteModel({
    required this.id,
    required this.tandaId,
    required this.clienteId,
    this.clienteNombre,
    required this.numeroTurno,
    this.haPagadoCuotaActual = false,
    this.haRecibidoBolsa = false,
    this.fechaRecepcionBolsa,
  });

  factory TandaParticipanteModel.fromMap(Map<String, dynamic> map) {
    return TandaParticipanteModel(
      id: map['id'] ?? '',
      tandaId: map['tanda_id'] ?? '',
      clienteId: map['cliente_id'] ?? '',
      clienteNombre: map['clientes']?['nombre'] ?? map['cliente_nombre'],
      numeroTurno: map['numero_turno'] ?? 0,
      haPagadoCuotaActual: map['ha_pagado_cuota_actual'] ?? false,
      haRecibidoBolsa: map['ha_recibido_bolsa'] ?? false,
      fechaRecepcionBolsa: map['fecha_recepcion_bolsa'] != null 
          ? DateTime.parse(map['fecha_recepcion_bolsa']) 
          : null,
    );
  }

  /// Para UPDATE (incluye id)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tanda_id': tandaId,
      'cliente_id': clienteId,
      'numero_turno': numeroTurno,
      'ha_pagado_cuota_actual': haPagadoCuotaActual,
      'ha_recibido_bolsa': haRecibidoBolsa,
      'fecha_recepcion_bolsa': fechaRecepcionBolsa?.toIso8601String(),
    };
  }

  /// Para INSERT (sin id)
  Map<String, dynamic> toMapForInsert() {
    return {
      'tanda_id': tandaId,
      'cliente_id': clienteId,
      'numero_turno': numeroTurno,
      'ha_pagado_cuota_actual': haPagadoCuotaActual,
      'ha_recibido_bolsa': haRecibidoBolsa,
      'fecha_recepcion_bolsa': fechaRecepcionBolsa?.toIso8601String(),
    };
  }

  /// Copia con modificaciones
  TandaParticipanteModel copyWith({
    String? id,
    String? tandaId,
    String? clienteId,
    String? clienteNombre,
    int? numeroTurno,
    bool? haPagadoCuotaActual,
    bool? haRecibidoBolsa,
    DateTime? fechaRecepcionBolsa,
  }) {
    return TandaParticipanteModel(
      id: id ?? this.id,
      tandaId: tandaId ?? this.tandaId,
      clienteId: clienteId ?? this.clienteId,
      clienteNombre: clienteNombre ?? this.clienteNombre,
      numeroTurno: numeroTurno ?? this.numeroTurno,
      haPagadoCuotaActual: haPagadoCuotaActual ?? this.haPagadoCuotaActual,
      haRecibidoBolsa: haRecibidoBolsa ?? this.haRecibidoBolsa,
      fechaRecepcionBolsa: fechaRecepcionBolsa ?? this.fechaRecepcionBolsa,
    );
  }
}
