/// Modelo para la tabla `clientes` de Supabase
/// Representa un cliente del sistema financiero
class ClienteModel {
  final String id;
  final String? negocioId;
  final String? sucursalId;
  final String? usuarioId;
  final String nombre;
  final String? apellidos;
  final String? email;
  final String? telefono;
  final String? direccion;
  final String? ciudad;
  final String? estado;
  final String? codigoPostal;
  final String? curp;
  final String? rfc;
  final String? ocupacion;
  final String? ingresoMensual;
  final String? fotoUrl;
  final String? ineUrl;
  final String? comprobanteDomicilioUrl;
  final double? latitud;
  final double? longitud;
  final String? notas;
  final bool activo;
  final DateTime createdAt;
  final DateTime? updatedAt;

  ClienteModel({
    required this.id,
    this.negocioId,
    this.sucursalId,
    this.usuarioId,
    required this.nombre,
    this.apellidos,
    this.email,
    this.telefono,
    this.direccion,
    this.ciudad,
    this.estado,
    this.codigoPostal,
    this.curp,
    this.rfc,
    this.ocupacion,
    this.ingresoMensual,
    this.fotoUrl,
    this.ineUrl,
    this.comprobanteDomicilioUrl,
    this.latitud,
    this.longitud,
    this.notas,
    this.activo = true,
    required this.createdAt,
    this.updatedAt,
  });

  /// Nombre completo del cliente
  String get nombreCompleto {
    if (apellidos != null && apellidos!.isNotEmpty) {
      return '$nombre $apellidos';
    }
    return nombre;
  }

  /// Iniciales del cliente para avatar
  String get iniciales {
    final partes = nombreCompleto.split(' ');
    if (partes.length >= 2) {
      return '${partes[0][0]}${partes[1][0]}'.toUpperCase();
    }
    return nombre.isNotEmpty ? nombre[0].toUpperCase() : '?';
  }

  factory ClienteModel.fromMap(Map<String, dynamic> map) {
    return ClienteModel(
      id: map['id'] ?? '',
      negocioId: map['negocio_id'],
      sucursalId: map['sucursal_id'],
      usuarioId: map['usuario_id'],
      nombre: map['nombre'] ?? '',
      apellidos: map['apellidos'],
      email: map['email'],
      telefono: map['telefono'],
      direccion: map['direccion'],
      ciudad: map['ciudad'],
      estado: map['estado'],
      codigoPostal: map['codigo_postal'],
      curp: map['curp'],
      rfc: map['rfc'],
      ocupacion: map['ocupacion'],
      ingresoMensual: map['ingreso_mensual']?.toString(),
      fotoUrl: map['foto_url'],
      ineUrl: map['ine_url'],
      comprobanteDomicilioUrl: map['comprobante_domicilio_url'],
      latitud: map['latitud'] != null ? double.tryParse(map['latitud'].toString()) : null,
      longitud: map['longitud'] != null ? double.tryParse(map['longitud'].toString()) : null,
      notas: map['notas'],
      activo: map['activo'] ?? true,
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'negocio_id': negocioId,
    'sucursal_id': sucursalId,
    'usuario_id': usuarioId,
    'nombre': nombre,
    'apellidos': apellidos,
    'email': email,
    'telefono': telefono,
    'direccion': direccion,
    'ciudad': ciudad,
    'estado': estado,
    'codigo_postal': codigoPostal,
    'curp': curp,
    'rfc': rfc,
    'ocupacion': ocupacion,
    'ingreso_mensual': ingresoMensual,
    'foto_url': fotoUrl,
    'ine_url': ineUrl,
    'comprobante_domicilio_url': comprobanteDomicilioUrl,
    'latitud': latitud,
    'longitud': longitud,
    'notas': notas,
    'activo': activo,
  };

  Map<String, dynamic> toMapForInsert() => {
    'negocio_id': negocioId,
    'sucursal_id': sucursalId,
    'usuario_id': usuarioId,
    'nombre': nombre,
    'apellidos': apellidos,
    'email': email,
    'telefono': telefono,
    'direccion': direccion,
    'ciudad': ciudad,
    'estado': estado,
    'codigo_postal': codigoPostal,
    'curp': curp,
    'rfc': rfc,
    'ocupacion': ocupacion,
    'ingreso_mensual': ingresoMensual,
    'foto_url': fotoUrl,
    'ine_url': ineUrl,
    'comprobante_domicilio_url': comprobanteDomicilioUrl,
    'latitud': latitud,
    'longitud': longitud,
    'notas': notas,
    'activo': activo,
  };

  ClienteModel copyWith({
    String? id,
    String? negocioId,
    String? sucursalId,
    String? usuarioId,
    String? nombre,
    String? apellidos,
    String? email,
    String? telefono,
    String? direccion,
    String? ciudad,
    String? estado,
    String? codigoPostal,
    String? curp,
    String? rfc,
    String? ocupacion,
    String? ingresoMensual,
    String? fotoUrl,
    String? ineUrl,
    String? comprobanteDomicilioUrl,
    double? latitud,
    double? longitud,
    String? notas,
    bool? activo,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ClienteModel(
      id: id ?? this.id,
      negocioId: negocioId ?? this.negocioId,
      sucursalId: sucursalId ?? this.sucursalId,
      usuarioId: usuarioId ?? this.usuarioId,
      nombre: nombre ?? this.nombre,
      apellidos: apellidos ?? this.apellidos,
      email: email ?? this.email,
      telefono: telefono ?? this.telefono,
      direccion: direccion ?? this.direccion,
      ciudad: ciudad ?? this.ciudad,
      estado: estado ?? this.estado,
      codigoPostal: codigoPostal ?? this.codigoPostal,
      curp: curp ?? this.curp,
      rfc: rfc ?? this.rfc,
      ocupacion: ocupacion ?? this.ocupacion,
      ingresoMensual: ingresoMensual ?? this.ingresoMensual,
      fotoUrl: fotoUrl ?? this.fotoUrl,
      ineUrl: ineUrl ?? this.ineUrl,
      comprobanteDomicilioUrl: comprobanteDomicilioUrl ?? this.comprobanteDomicilioUrl,
      latitud: latitud ?? this.latitud,
      longitud: longitud ?? this.longitud,
      notas: notas ?? this.notas,
      activo: activo ?? this.activo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() => 'ClienteModel(id: $id, nombre: $nombreCompleto)';
}
