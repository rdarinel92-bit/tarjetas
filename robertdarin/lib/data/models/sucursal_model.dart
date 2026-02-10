/// Modelo para la tabla `sucursales` de Supabase
/// Representa una sucursal de un negocio
class SucursalModel {
  final String id;
  final String? negocioId;
  final String nombre;
  final String? direccion;
  final String? ciudad;
  final String? estado;
  final String? codigoPostal;
  final String? telefono;
  final String? email;
  final String? gerenteId;
  final double? latitud;
  final double? longitud;
  final String? horarioApertura;
  final String? horarioCierre;
  final bool activa;
  final DateTime createdAt;
  final DateTime? updatedAt;

  SucursalModel({
    required this.id,
    this.negocioId,
    required this.nombre,
    this.direccion,
    this.ciudad,
    this.estado,
    this.codigoPostal,
    this.telefono,
    this.email,
    this.gerenteId,
    this.latitud,
    this.longitud,
    this.horarioApertura,
    this.horarioCierre,
    this.activa = true,
    required this.createdAt,
    this.updatedAt,
  });

  /// Dirección completa formateada
  String get direccionCompleta {
    final partes = <String>[];
    if (direccion != null && direccion!.isNotEmpty) partes.add(direccion!);
    if (ciudad != null && ciudad!.isNotEmpty) partes.add(ciudad!);
    if (estado != null && estado!.isNotEmpty) partes.add(estado!);
    if (codigoPostal != null && codigoPostal!.isNotEmpty) partes.add('C.P. $codigoPostal');
    return partes.join(', ');
  }

  /// Horario formateado
  String get horario {
    if (horarioApertura != null && horarioCierre != null) {
      return '$horarioApertura - $horarioCierre';
    }
    return 'No especificado';
  }

  factory SucursalModel.fromMap(Map<String, dynamic> map) {
    return SucursalModel(
      id: map['id'] ?? '',
      negocioId: map['negocio_id'],
      nombre: map['nombre'] ?? '',
      direccion: map['direccion'],
      ciudad: map['ciudad'],
      estado: map['estado'],
      codigoPostal: map['codigo_postal'],
      telefono: map['telefono'],
      email: map['email'],
      gerenteId: map['gerente_id'],
      latitud: map['latitud'] != null ? double.tryParse(map['latitud'].toString()) : null,
      longitud: map['longitud'] != null ? double.tryParse(map['longitud'].toString()) : null,
      horarioApertura: map['horario_apertura'],
      horarioCierre: map['horario_cierre'],
      activa: map['activa'] ?? true,
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'negocio_id': negocioId,
    'nombre': nombre,
    'direccion': direccion,
    'ciudad': ciudad,
    'estado': estado,
    'codigo_postal': codigoPostal,
    'telefono': telefono,
    'email': email,
    'gerente_id': gerenteId,
    'latitud': latitud,
    'longitud': longitud,
    'horario_apertura': horarioApertura,
    'horario_cierre': horarioCierre,
    'activa': activa,
  };

  Map<String, dynamic> toMapForInsert() => {
    'negocio_id': negocioId,
    'nombre': nombre,
    'direccion': direccion,
    'ciudad': ciudad,
    'estado': estado,
    'codigo_postal': codigoPostal,
    'telefono': telefono,
    'email': email,
    'gerente_id': gerenteId,
    'latitud': latitud,
    'longitud': longitud,
    'horario_apertura': horarioApertura,
    'horario_cierre': horarioCierre,
    'activa': activa,
  };

  SucursalModel copyWith({
    String? id,
    String? negocioId,
    String? nombre,
    String? direccion,
    String? ciudad,
    String? estado,
    String? codigoPostal,
    String? telefono,
    String? email,
    String? gerenteId,
    double? latitud,
    double? longitud,
    String? horarioApertura,
    String? horarioCierre,
    bool? activa,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SucursalModel(
      id: id ?? this.id,
      negocioId: negocioId ?? this.negocioId,
      nombre: nombre ?? this.nombre,
      direccion: direccion ?? this.direccion,
      ciudad: ciudad ?? this.ciudad,
      estado: estado ?? this.estado,
      codigoPostal: codigoPostal ?? this.codigoPostal,
      telefono: telefono ?? this.telefono,
      email: email ?? this.email,
      gerenteId: gerenteId ?? this.gerenteId,
      latitud: latitud ?? this.latitud,
      longitud: longitud ?? this.longitud,
      horarioApertura: horarioApertura ?? this.horarioApertura,
      horarioCierre: horarioCierre ?? this.horarioCierre,
      activa: activa ?? this.activa,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() => 'SucursalModel(id: $id, nombre: $nombre)';
}
