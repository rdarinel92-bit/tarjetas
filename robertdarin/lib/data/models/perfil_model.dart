class PerfilModel {
  final String id;
  final String? nombre;
  final String? telefono;
  final String? fotoUrl;
  final DateTime? creado;
  final DateTime? actualizado;

  PerfilModel({
    required this.id,
    this.nombre,
    this.telefono,
    this.fotoUrl,
    this.creado,
    this.actualizado,
  });

  factory PerfilModel.fromMap(Map<String, dynamic> map) {
    return PerfilModel(
      id: map['id']?.toString() ?? '',
      nombre: map['nombre']?.toString(),
      telefono: map['telefono']?.toString(),
      fotoUrl: map['foto_url']?.toString(),
      creado: map['created_at'] != null ? DateTime.tryParse(map['created_at']) : null,
      actualizado: map['updated_at'] != null ? DateTime.tryParse(map['updated_at']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'telefono': telefono,
      'foto_url': fotoUrl,
    };
  }
}
