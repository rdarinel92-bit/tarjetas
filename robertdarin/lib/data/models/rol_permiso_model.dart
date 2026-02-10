class RolPermisoModel {
  final String id;
  final String rolId;
  final String permisoId;
  final DateTime createdAt;

  RolPermisoModel({
    required this.id,
    required this.rolId,
    required this.permisoId,
    required this.createdAt,
  });

  factory RolPermisoModel.fromMap(Map<String, dynamic> map) {
    return RolPermisoModel(
      id: map['id'],
      rolId: map['rol_id'],
      permisoId: map['permiso_id'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'rol_id': rolId,
      'permiso_id': permisoId,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
