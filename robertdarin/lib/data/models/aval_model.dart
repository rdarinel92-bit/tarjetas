/// ══════════════════════════════════════════════════════════════════════════════
/// AVAL MODEL - Robert Darin Fintech V10.26
/// ══════════════════════════════════════════════════════════════════════════════
/// Modelo completo para avales incluyendo documentos y FCM
/// ══════════════════════════════════════════════════════════════════════════════

class AvalModel {
  final String id;
  final String nombre;
  final String email;
  final String telefono;
  final String direccion;
  final String relacion;
  final String clienteId;
  final String? usuarioId;
  final String? identificacion;
  final String? negocioId;
  
  // V10.26 - Documentos directos
  final String? ineUrl;
  final String? ineReversoUrl;
  final String? domicilioUrl;
  final String? selfieUrl;
  final String? ingresosUrl;
  
  // V10.26 - Verificación y estado
  final bool verificado;
  final bool activo;
  final bool ubicacionConsentida;
  
  // V10.26 - Firma digital
  final String? firmaDigitalUrl;
  final DateTime? fechaFirma;
  
  // V10.26 - Ubicación y check-ins
  final double? ultimaLatitud;
  final double? ultimaLongitud;
  final DateTime? ultimoCheckin;
  
  // V10.26 - Push Notifications
  final String? fcmToken;
  
  // Timestamps
  final DateTime? createdAt;
  final DateTime? updatedAt;

  AvalModel({
    required this.id,
    required this.nombre,
    required this.email,
    required this.telefono,
    required this.direccion,
    required this.relacion,
    required this.clienteId,
    this.usuarioId,
    this.identificacion,
    this.negocioId,
    this.ineUrl,
    this.ineReversoUrl,
    this.domicilioUrl,
    this.selfieUrl,
    this.ingresosUrl,
    this.verificado = false,
    this.activo = true,
    this.ubicacionConsentida = false,
    this.firmaDigitalUrl,
    this.fechaFirma,
    this.ultimaLatitud,
    this.ultimaLongitud,
    this.ultimoCheckin,
    this.fcmToken,
    this.createdAt,
    this.updatedAt,
  });

  factory AvalModel.fromMap(Map<String, dynamic> map) {
    return AvalModel(
      id: map['id']?.toString() ?? '',
      nombre: map['nombre']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      telefono: map['telefono']?.toString() ?? '',
      direccion: map['direccion']?.toString() ?? '',
      relacion: map['relacion']?.toString() ?? '',
      clienteId: map['cliente_id']?.toString() ?? '',
      usuarioId: map['usuario_id']?.toString(),
      identificacion: map['identificacion']?.toString(),
      negocioId: map['negocio_id']?.toString(),
      ineUrl: map['ine_url']?.toString(),
      ineReversoUrl: map['ine_reverso_url']?.toString(),
      domicilioUrl: map['domicilio_url']?.toString(),
      selfieUrl: map['selfie_url']?.toString(),
      ingresosUrl: map['ingresos_url']?.toString(),
      verificado: map['verificado'] == true,
      activo: map['activo'] != false,
      ubicacionConsentida: map['ubicacion_consentida'] == true,
      firmaDigitalUrl: map['firma_digital_url']?.toString(),
      fechaFirma: map['fecha_firma'] != null 
          ? DateTime.tryParse(map['fecha_firma'].toString()) 
          : null,
      ultimaLatitud: map['ultima_latitud'] != null 
          ? double.tryParse(map['ultima_latitud'].toString()) 
          : null,
      ultimaLongitud: map['ultima_longitud'] != null 
          ? double.tryParse(map['ultima_longitud'].toString()) 
          : null,
      ultimoCheckin: map['ultimo_checkin'] != null 
          ? DateTime.tryParse(map['ultimo_checkin'].toString()) 
          : null,
      fcmToken: map['fcm_token']?.toString(),
      createdAt: map['created_at'] != null 
          ? DateTime.tryParse(map['created_at'].toString()) 
          : null,
      updatedAt: map['updated_at'] != null 
          ? DateTime.tryParse(map['updated_at'].toString()) 
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'email': email,
      'telefono': telefono,
      'direccion': direccion,
      'relacion': relacion,
      'cliente_id': clienteId,
      'usuario_id': usuarioId,
      'identificacion': identificacion,
      'negocio_id': negocioId,
      'ine_url': ineUrl,
      'ine_reverso_url': ineReversoUrl,
      'domicilio_url': domicilioUrl,
      'selfie_url': selfieUrl,
      'ingresos_url': ingresosUrl,
      'verificado': verificado,
      'activo': activo,
      'ubicacion_consentida': ubicacionConsentida,
      'firma_digital_url': firmaDigitalUrl,
      'fecha_firma': fechaFirma?.toIso8601String(),
      'ultima_latitud': ultimaLatitud,
      'ultima_longitud': ultimaLongitud,
      'ultimo_checkin': ultimoCheckin?.toIso8601String(),
      'fcm_token': fcmToken,
    };
  }

  /// toMap para INSERT (sin id, Supabase lo genera)
  Map<String, dynamic> toMapForInsert() {
    return {
      'nombre': nombre,
      'email': email,
      'telefono': telefono,
      'direccion': direccion,
      'relacion': relacion,
      'cliente_id': clienteId,
      'usuario_id': usuarioId,
      'identificacion': identificacion,
      'negocio_id': negocioId,
      'ine_url': ineUrl,
      'ine_reverso_url': ineReversoUrl,
      'domicilio_url': domicilioUrl,
      'selfie_url': selfieUrl,
      'ingresos_url': ingresosUrl,
      'verificado': verificado,
      'activo': activo,
      'ubicacion_consentida': ubicacionConsentida,
    };
  }

  /// Verificar si tiene todos los documentos requeridos
  bool get documentosCompletos {
    return ineUrl != null && 
           ineReversoUrl != null && 
           domicilioUrl != null && 
           selfieUrl != null;
  }

  /// Contar documentos subidos
  int get documentosSubidos {
    int count = 0;
    if (ineUrl != null) count++;
    if (ineReversoUrl != null) count++;
    if (domicilioUrl != null) count++;
    if (selfieUrl != null) count++;
    if (ingresosUrl != null) count++;
    return count;
  }

  /// Copiar con modificaciones
  AvalModel copyWith({
    String? id,
    String? nombre,
    String? email,
    String? telefono,
    String? direccion,
    String? relacion,
    String? clienteId,
    String? usuarioId,
    String? identificacion,
    String? negocioId,
    String? ineUrl,
    String? ineReversoUrl,
    String? domicilioUrl,
    String? selfieUrl,
    String? ingresosUrl,
    bool? verificado,
    bool? activo,
    bool? ubicacionConsentida,
    String? firmaDigitalUrl,
    DateTime? fechaFirma,
    double? ultimaLatitud,
    double? ultimaLongitud,
    DateTime? ultimoCheckin,
    String? fcmToken,
  }) {
    return AvalModel(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      email: email ?? this.email,
      telefono: telefono ?? this.telefono,
      direccion: direccion ?? this.direccion,
      relacion: relacion ?? this.relacion,
      clienteId: clienteId ?? this.clienteId,
      usuarioId: usuarioId ?? this.usuarioId,
      identificacion: identificacion ?? this.identificacion,
      negocioId: negocioId ?? this.negocioId,
      ineUrl: ineUrl ?? this.ineUrl,
      ineReversoUrl: ineReversoUrl ?? this.ineReversoUrl,
      domicilioUrl: domicilioUrl ?? this.domicilioUrl,
      selfieUrl: selfieUrl ?? this.selfieUrl,
      ingresosUrl: ingresosUrl ?? this.ingresosUrl,
      verificado: verificado ?? this.verificado,
      activo: activo ?? this.activo,
      ubicacionConsentida: ubicacionConsentida ?? this.ubicacionConsentida,
      firmaDigitalUrl: firmaDigitalUrl ?? this.firmaDigitalUrl,
      fechaFirma: fechaFirma ?? this.fechaFirma,
      ultimaLatitud: ultimaLatitud ?? this.ultimaLatitud,
      ultimaLongitud: ultimaLongitud ?? this.ultimaLongitud,
      ultimoCheckin: ultimoCheckin ?? this.ultimoCheckin,
      fcmToken: fcmToken ?? this.fcmToken,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
