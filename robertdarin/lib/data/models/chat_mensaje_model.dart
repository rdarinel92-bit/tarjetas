class ChatMensajeModel {
  final String id;
  final String conversacionId;
  final String remitenteUsuarioId;
  final String tipoMensaje;
  final String? contenidoTexto;
  final String? archivoUrl;
  final double? latitud;
  final double? longitud;
  final String hashContenido;
  final bool esSistema;
  final DateTime createdAt;

  ChatMensajeModel({
    required this.id,
    required this.conversacionId,
    required this.remitenteUsuarioId,
    required this.tipoMensaje,
    required this.contenidoTexto,
    required this.archivoUrl,
    required this.latitud,
    required this.longitud,
    required this.hashContenido,
    required this.esSistema,
    required this.createdAt,
  });

  factory ChatMensajeModel.fromMap(Map<String, dynamic> map) {
    return ChatMensajeModel(
      id: map['id'],
      conversacionId: map['conversacion_id'],
      remitenteUsuarioId: map['remitente_usuario_id'],
      tipoMensaje: map['tipo_mensaje'],
      contenidoTexto: map['contenido_texto'],
      archivoUrl: map['archivo_url'],
      latitud: map['latitud'] != null ? (map['latitud'] as num).toDouble() : null,
      longitud: map['longitud'] != null ? (map['longitud'] as num).toDouble() : null,
      hashContenido: map['hash_contenido'],
      esSistema: map['es_sistema'] ?? false,
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'conversacion_id': conversacionId,
      'remitente_usuario_id': remitenteUsuarioId,
      'tipo_mensaje': tipoMensaje,
      'contenido_texto': contenidoTexto,
      'archivo_url': archivoUrl,
      'latitud': latitud,
      'longitud': longitud,
      'hash_contenido': hashContenido,
      'es_sistema': esSistema,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
