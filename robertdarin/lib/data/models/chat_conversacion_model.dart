class ChatConversacionModel {
  final String id;
  final String tipoConversacion;
  final String? clienteId;
  final String? avalId;
  final String? prestamoId;
  final String? tandaId;
  final String creadoPorUsuarioId;
  final String estado;
  final DateTime createdAt;

  ChatConversacionModel({
    required this.id,
    required this.tipoConversacion,
    required this.clienteId,
    required this.avalId,
    required this.prestamoId,
    required this.tandaId,
    required this.creadoPorUsuarioId,
    required this.estado,
    required this.createdAt,
  });

  factory ChatConversacionModel.fromMap(Map<String, dynamic> map) {
    return ChatConversacionModel(
      id: map['id'],
      tipoConversacion: map['tipo_conversacion'],
      clienteId: map['cliente_id'],
      avalId: map['aval_id'],
      prestamoId: map['prestamo_id'],
      tandaId: map['tanda_id'],
      creadoPorUsuarioId: map['creado_por_usuario_id'],
      estado: map['estado'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tipo_conversacion': tipoConversacion,
      'cliente_id': clienteId,
      'aval_id': avalId,
      'prestamo_id': prestamoId,
      'tanda_id': tandaId,
      'creado_por_usuario_id': creadoPorUsuarioId,
      'estado': estado,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
