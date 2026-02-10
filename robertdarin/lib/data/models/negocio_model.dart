/// Modelo para la tabla `negocios` de Supabase
/// Representa un negocio en el sistema multi-tenant
class NegocioModel {
  final String id;
  final String nombre;
  final String? tipo; // fintech, aires, purificadora, ventas, nice
  final String? descripcion;
  final String? logoUrl;
  final String? direccion;
  final String? telefono;
  final String? email;
  final String? sitioWeb;
  final String? rfc;
  final String? razonSocial;
  final String? regimenFiscal;
  final bool activo;
  final DateTime createdAt;
  final DateTime? updatedAt;

  NegocioModel({
    required this.id,
    required this.nombre,
    this.tipo,
    this.descripcion,
    this.logoUrl,
    this.direccion,
    this.telefono,
    this.email,
    this.sitioWeb,
    this.rfc,
    this.razonSocial,
    this.regimenFiscal,
    this.activo = true,
    required this.createdAt,
    this.updatedAt,
  });

  /// Icono según el tipo de negocio
  String get icono {
    switch (tipo) {
      case 'fintech':
        return '💰';
      case 'aires':
      case 'climas':
        return '❄️';
      case 'purificadora':
        return '💧';
      case 'ventas':
        return '🛒';
      case 'nice':
        return '💎';
      default:
        return '🏢';
    }
  }

  factory NegocioModel.fromMap(Map<String, dynamic> map) {
    return NegocioModel(
      id: map['id'] ?? '',
      nombre: map['nombre'] ?? '',
      tipo: map['tipo'],
      descripcion: map['descripcion'],
      logoUrl: map['logo_url'],
      direccion: map['direccion'],
      telefono: map['telefono'],
      email: map['email'],
      sitioWeb: map['sitio_web'],
      rfc: map['rfc'],
      razonSocial: map['razon_social'],
      regimenFiscal: map['regimen_fiscal'],
      activo: map['activo'] ?? true,
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'nombre': nombre,
    'tipo': tipo,
    'descripcion': descripcion,
    'logo_url': logoUrl,
    'direccion': direccion,
    'telefono': telefono,
    'email': email,
    'sitio_web': sitioWeb,
    'rfc': rfc,
    'razon_social': razonSocial,
    'regimen_fiscal': regimenFiscal,
    'activo': activo,
  };

  Map<String, dynamic> toMapForInsert() => {
    'nombre': nombre,
    'tipo': tipo,
    'descripcion': descripcion,
    'logo_url': logoUrl,
    'direccion': direccion,
    'telefono': telefono,
    'email': email,
    'sitio_web': sitioWeb,
    'rfc': rfc,
    'razon_social': razonSocial,
    'regimen_fiscal': regimenFiscal,
    'activo': activo,
  };

  NegocioModel copyWith({
    String? id,
    String? nombre,
    String? tipo,
    String? descripcion,
    String? logoUrl,
    String? direccion,
    String? telefono,
    String? email,
    String? sitioWeb,
    String? rfc,
    String? razonSocial,
    String? regimenFiscal,
    bool? activo,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NegocioModel(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      tipo: tipo ?? this.tipo,
      descripcion: descripcion ?? this.descripcion,
      logoUrl: logoUrl ?? this.logoUrl,
      direccion: direccion ?? this.direccion,
      telefono: telefono ?? this.telefono,
      email: email ?? this.email,
      sitioWeb: sitioWeb ?? this.sitioWeb,
      rfc: rfc ?? this.rfc,
      razonSocial: razonSocial ?? this.razonSocial,
      regimenFiscal: regimenFiscal ?? this.regimenFiscal,
      activo: activo ?? this.activo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() => 'NegocioModel(id: $id, nombre: $nombre, tipo: $tipo)';
}
