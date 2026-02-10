class RolModel {
  final String id;
  final String nombre;
  final String descripcion;
  final DateTime createdAt;

  RolModel({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.createdAt,
  });

  factory RolModel.fromMap(Map<String, dynamic> map) {
    return RolModel(
      id: map['id'],
      nombre: map['nombre'],
      descripcion: map['descripcion'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'descripcion': descripcion,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
