class TandaModel {
  final String id;
  final String nombre;
  final double montoPorPersona;
  final int numeroParticipantes;
  final int turnoActual;
  final String frecuencia; // Semanal, Quincenal, Mensual
  final DateTime fechaInicio;
  final DateTime? fechaFin;
  final String estado;
  final String? organizadorId;
  // V10.30: Campos multi-tenant
  final String? negocioId;
  final String? sucursalId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  TandaModel({
    required this.id,
    required this.nombre,
    required this.montoPorPersona,
    required this.numeroParticipantes,
    this.turnoActual = 1,
    this.frecuencia = 'Semanal',
    required this.fechaInicio,
    this.fechaFin,
    required this.estado,
    this.organizadorId,
    this.negocioId,
    this.sucursalId,
    this.createdAt,
    this.updatedAt,
  });

  /// Calcula el monto total de la bolsa
  double get montoBolsa => montoPorPersona * numeroParticipantes;

  /// Calcula el progreso de la tanda (turnos completados)
  /// V10.55: Corregido para ser consistente - (turnoActual-1)/total
  double get progreso => numeroParticipantes > 0 ? (turnoActual - 1) / numeroParticipantes : 0.0;

  factory TandaModel.fromMap(Map<String, dynamic> map) {
    return TandaModel(
      id: map['id'] ?? '',
      nombre: map['nombre'] ?? '',
      montoPorPersona: (map['monto_por_persona'] as num?)?.toDouble() ?? 0,
      numeroParticipantes: map['numero_participantes'] ?? 0,
      turnoActual: map['turno'] ?? 1,
      frecuencia: map['frecuencia'] ?? 'Semanal',
      fechaInicio: DateTime.parse(map['fecha_inicio'] ?? DateTime.now().toIso8601String()),
      fechaFin: map['fecha_fin'] != null ? DateTime.parse(map['fecha_fin']) : null,
      estado: map['estado'] ?? 'activa',
      organizadorId: map['organizador_id'],
      negocioId: map['negocio_id'],
      sucursalId: map['sucursal_id'],
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
    );
  }

  /// Para UPDATE (incluye id)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'monto_por_persona': montoPorPersona,
      'numero_participantes': numeroParticipantes,
      'turno': turnoActual,
      'frecuencia': frecuencia,
      'fecha_inicio': fechaInicio.toIso8601String(),
      'fecha_fin': fechaFin?.toIso8601String(),
      'estado': estado,
      'organizador_id': organizadorId,
      if (negocioId != null) 'negocio_id': negocioId,
      if (sucursalId != null) 'sucursal_id': sucursalId,
    };
  }

  /// Para INSERT (sin id, Supabase lo genera)
  Map<String, dynamic> toMapForInsert() {
    return {
      'nombre': nombre,
      'monto_por_persona': montoPorPersona,
      'numero_participantes': numeroParticipantes,
      'turno': turnoActual,
      'frecuencia': frecuencia,
      'fecha_inicio': fechaInicio.toIso8601String(),
      'fecha_fin': fechaFin?.toIso8601String(),
      'estado': estado,
      'organizador_id': organizadorId,
      if (negocioId != null) 'negocio_id': negocioId,
      if (sucursalId != null) 'sucursal_id': sucursalId,
    };
  }

  /// Copia con modificaciones
  TandaModel copyWith({
    String? id,
    String? nombre,
    double? montoPorPersona,
    int? numeroParticipantes,
    int? turnoActual,
    String? frecuencia,
    DateTime? fechaInicio,
    DateTime? fechaFin,
    String? estado,
    String? organizadorId,
    String? negocioId,
    String? sucursalId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TandaModel(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      montoPorPersona: montoPorPersona ?? this.montoPorPersona,
      numeroParticipantes: numeroParticipantes ?? this.numeroParticipantes,
      turnoActual: turnoActual ?? this.turnoActual,
      frecuencia: frecuencia ?? this.frecuencia,
      fechaInicio: fechaInicio ?? this.fechaInicio,
      fechaFin: fechaFin ?? this.fechaFin,
      estado: estado ?? this.estado,
      organizadorId: organizadorId ?? this.organizadorId,
      negocioId: negocioId ?? this.negocioId,
      sucursalId: sucursalId ?? this.sucursalId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
