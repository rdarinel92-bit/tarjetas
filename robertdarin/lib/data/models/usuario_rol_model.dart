class UsuarioRolModel {
  final String? id;
  final String usuarioId;
  final String rolId;

  UsuarioRolModel({
    this.id,
    required this.usuarioId,
    required this.rolId,
  });

  factory UsuarioRolModel.fromMap(Map<String, dynamic> map) {
    return UsuarioRolModel(
      id: map['id']?.toString(),
      usuarioId: map['usuario_id']?.toString() ?? '',
      rolId: map['rol_id']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'usuario_id': usuarioId,
      'rol_id': rolId,
    };
  }
}
