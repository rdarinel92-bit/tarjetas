class AuditoriaAccesoModel {
  final String id;
  final String usuarioId;
  final String rolId;
  final String accion;
  final String entidad;
  final String entidadId;
  final String? ip;
  final double? latitud;
  final double? longitud;
  final String? dispositivo;
  final String hashContenido;
  final DateTime createdAt;

  AuditoriaAccesoModel({
    required this.id,
    required this.usuarioId,
    required this.rolId,
    required this.accion,
    required this.entidad,
    required this.entidadId,
    required this.ip,
    required this.latitud,
    required this.longitud,
    required this.dispositivo,
    required this.hashContenido,
    required this.createdAt,
  });

  factory AuditoriaAccesoModel.fromMap(Map<String, dynamic> map) {
    return AuditoriaAccesoModel(
      id: map['id'],
      usuarioId: map['usuario_id'],
      rolId: map['rol_id'],
      accion: map['accion'],
      entidad: map['entidad'],
      entidadId: map['entidad_id'],
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
      'usuario_id': usuarioId,
      'rol_id': rolId,
      'accion': accion,
      'entidad': entidad,
      'entidad_id': entidadId,
      'ip': ip,
      'latitud': latitud,
      'longitud': longitud,
      'dispositivo': dispositivo,
      'hash_contenido': hashContenido,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
