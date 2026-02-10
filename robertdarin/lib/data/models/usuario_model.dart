class UsuarioModel {
  final String? id;
  final String email;
  final String? telefono;
  final String? nombreCompleto;
  final String? rolId;
  final DateTime? creado;
  final DateTime? actualizado;

  // Getter de compatibilidad para código que usa 'nombre'
  String get nombre => nombreCompleto ?? '';

  UsuarioModel({
    this.id,
    required this.email,
    this.telefono,
    this.nombreCompleto,
    this.rolId,
    this.creado,
    this.actualizado,
  });

  factory UsuarioModel.fromMap(Map<String, dynamic> map) {
    return UsuarioModel(
      id: map['id']?.toString(),
      email: map['email']?.toString() ?? '',
      telefono: map['telefono']?.toString(),
      nombreCompleto: map['nombre_completo']?.toString(),
      rolId: map['rol_id']?.toString(),
      creado: map['created_at'] != null ? DateTime.tryParse(map['created_at']) : null,
      actualizado: map['updated_at'] != null ? DateTime.tryParse(map['updated_at']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'telefono': telefono,
      'nombre_completo': nombreCompleto,
      'rol_id': rolId,
    };
  }
}
