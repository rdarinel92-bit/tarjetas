/// Modelo para la tabla `calendario` de Supabase
/// Representa un evento o recordatorio en el calendario
class CalendarioModel {
  final String id;
  final String titulo;
  final String? descripcion;
  final DateTime fecha;
  final DateTime? fechaFin;
  final String? tipo; // pago, cobranza, reunion, recordatorio
  final String? usuarioId;
  final String? clienteId;
  final String? prestamoId;
  final bool completado;
  final DateTime createdAt;

  CalendarioModel({
    required this.id,
    required this.titulo,
    this.descripcion,
    required this.fecha,
    this.fechaFin,
    this.tipo,
    this.usuarioId,
    this.clienteId,
    this.prestamoId,
    this.completado = false,
    required this.createdAt,
  });

  /// Color según tipo de evento
  String get colorHex {
    switch (tipo) {
      case 'pago':
        return '#10B981'; // verde
      case 'cobranza':
        return '#F59E0B'; // amarillo
      case 'reunion':
        return '#3B82F6'; // azul
      case 'recordatorio':
        return '#8B5CF6'; // morado
      default:
        return '#6B7280'; // gris
    }
  }

  /// Icono según tipo
  String get icono {
    switch (tipo) {
      case 'pago':
        return '💰';
      case 'cobranza':
        return '📋';
      case 'reunion':
        return '👥';
      case 'recordatorio':
        return '🔔';
      default:
        return '📅';
    }
  }

  /// Si es un evento de todo el día
  bool get esTodoElDia => fechaFin == null;

  factory CalendarioModel.fromMap(Map<String, dynamic> map) {
    return CalendarioModel(
      id: map['id'] ?? '',
      titulo: map['titulo'] ?? '',
      descripcion: map['descripcion'],
      fecha: DateTime.parse(map['fecha'] ?? DateTime.now().toIso8601String()),
      fechaFin: map['fecha_fin'] != null ? DateTime.parse(map['fecha_fin']) : null,
      tipo: map['tipo'],
      usuarioId: map['usuario_id'],
      clienteId: map['cliente_id'],
      prestamoId: map['prestamo_id'],
      completado: map['completado'] ?? false,
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'titulo': titulo,
    'descripcion': descripcion,
    'fecha': fecha.toIso8601String(),
    'fecha_fin': fechaFin?.toIso8601String(),
    'tipo': tipo,
    'usuario_id': usuarioId,
    'cliente_id': clienteId,
    'prestamo_id': prestamoId,
    'completado': completado,
  };

  Map<String, dynamic> toMapForInsert() => {
    'titulo': titulo,
    'descripcion': descripcion,
    'fecha': fecha.toIso8601String(),
    'fecha_fin': fechaFin?.toIso8601String(),
    'tipo': tipo,
    'usuario_id': usuarioId,
    'cliente_id': clienteId,
    'prestamo_id': prestamoId,
    'completado': completado,
  };

  CalendarioModel copyWith({
    String? id,
    String? titulo,
    String? descripcion,
    DateTime? fecha,
    DateTime? fechaFin,
    String? tipo,
    String? usuarioId,
    String? clienteId,
    String? prestamoId,
    bool? completado,
    DateTime? createdAt,
  }) {
    return CalendarioModel(
      id: id ?? this.id,
      titulo: titulo ?? this.titulo,
      descripcion: descripcion ?? this.descripcion,
      fecha: fecha ?? this.fecha,
      fechaFin: fechaFin ?? this.fechaFin,
      tipo: tipo ?? this.tipo,
      usuarioId: usuarioId ?? this.usuarioId,
      clienteId: clienteId ?? this.clienteId,
      prestamoId: prestamoId ?? this.prestamoId,
      completado: completado ?? this.completado,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() => 'CalendarioModel(id: $id, titulo: $titulo, fecha: $fecha)';
}
