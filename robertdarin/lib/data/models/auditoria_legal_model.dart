class AuditoriaLegalModel {
  final String id;
  final String tipoEntidad;
  final String entidadId;
  final String accion;
  final String usuarioId;
  final String ip;
  final double? latitud;
  final double? longitud;
  final String dispositivo;
  final String hashContenido;
  final DateTime createdAt;

  AuditoriaLegalModel({
    required this.id,
    required this.tipoEntidad,
    required this.entidadId,
    required this.accion,
    required this.usuarioId,
    required this.ip,
    this.latitud,
    this.longitud,
    required this.dispositivo,
    required this.hashContenido,
    required this.createdAt,
  });

  factory AuditoriaLegalModel.fromMap(Map<String, dynamic> map) {
    return AuditoriaLegalModel(
      id: map['id'],
      tipoEntidad: map['tipo_entidad'],
      entidadId: map['entidad_id'],
      accion: map['accion'],
      usuarioId: map['usuario_id'],
      ip: map['ip'],
      latitud: map['latitud'] != null ? (map['latitud'] as num).toDouble() : null,
      longitud: map['longitud'] != null ? (map['longitud'] as num).toDouble() : null,
      dispositivo: map['dispositivo'],
      hashContenido: map['hash_contenido'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tipo_entidad': tipoEntidad,
      'entidad_id': entidadId,
      'accion': accion,
      'usuario_id': usuarioId,
      'ip': ip,
      'latitud': latitud,
      'longitud': longitud,
      'dispositivo': dispositivo,
      'hash_contenido': hashContenido,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
