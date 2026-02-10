class ChatParticipanteModel {
  final String id;
  final String conversacionId;
  final String usuarioId;
  final String rolEnChat;
  final bool notificacionesActivas;
  final DateTime createdAt;

  ChatParticipanteModel({
    required this.id,
    required this.conversacionId,
    required this.usuarioId,
    required this.rolEnChat,
    required this.notificacionesActivas,
    required this.createdAt,
  });

  factory ChatParticipanteModel.fromMap(Map<String, dynamic> map) {
    final silenciado = map['silenciado'];
    return ChatParticipanteModel(
      id: map['id'],
      conversacionId: map['conversacion_id'],
      usuarioId: map['usuario_id'],
      rolEnChat: map['rol_chat'] ?? map['rol_en_chat'] ?? '',
      notificacionesActivas:
          map['notificaciones_activas'] ?? (silenciado == null ? true : !silenciado),
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'conversacion_id': conversacionId,
      'usuario_id': usuarioId,
      'rol_chat': rolEnChat,
      'silenciado': !notificacionesActivas,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
