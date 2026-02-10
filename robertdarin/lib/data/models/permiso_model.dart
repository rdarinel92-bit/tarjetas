class PermisoModel {
  final String id;
  final String clavePermiso;
  final String descripcion;
  final DateTime createdAt;

  PermisoModel({
    required this.id,
    required this.clavePermiso,
    required this.descripcion,
    required this.createdAt,
  });

  factory PermisoModel.fromMap(Map<String, dynamic> map) {
    return PermisoModel(
      id: map['id'],
      clavePermiso: map['clave_permiso'],
      descripcion: map['descripcion'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'clave_permiso': clavePermiso,
      'descripcion': descripcion,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
