/// ══════════════════════════════════════════════════════════════════════════════
/// CONFIGURACIÓN API MODEL - Robert Darin Fintech V10.26
/// ══════════════════════════════════════════════════════════════════════════════
/// Modelo para configuración de APIs externas (Firebase, Stripe, etc.)
/// Tabla: configuracion_apis
/// ══════════════════════════════════════════════════════════════════════════════

class ConfiguracionApiModel {
  final String id;
  final String? negocioId;
  final String servicio; // firebase_fcm, stripe, twilio, etc.
  final bool activo;
  final bool modoTest;
  final String? publishableKey;
  final String? secretKey;
  final String? webhookSecret;
  final String? apiKey;
  final Map<String, dynamic> configuracion;
  final DateTime? ultimaVerificacion;
  final String estadoConexion; // ok, error, no_verificado
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ConfiguracionApiModel({
    required this.id,
    this.negocioId,
    required this.servicio,
    this.activo = false,
    this.modoTest = true,
    this.publishableKey,
    this.secretKey,
    this.webhookSecret,
    this.apiKey,
    this.configuracion = const {},
    this.ultimaVerificacion,
    this.estadoConexion = 'no_verificado',
    this.createdAt,
    this.updatedAt,
  });

  factory ConfiguracionApiModel.fromMap(Map<String, dynamic> map) {
    return ConfiguracionApiModel(
      id: map['id']?.toString() ?? '',
      negocioId: map['negocio_id']?.toString(),
      servicio: map['servicio']?.toString() ?? '',
      activo: map['activo'] == true,
      modoTest: map['modo_test'] == true,
      publishableKey: map['publishable_key']?.toString(),
      secretKey: map['secret_key']?.toString(),
      webhookSecret: map['webhook_secret']?.toString(),
      apiKey: map['api_key']?.toString(),
      configuracion: map['configuracion'] is Map 
          ? Map<String, dynamic>.from(map['configuracion']) 
          : {},
      ultimaVerificacion: map['ultima_verificacion'] != null 
          ? DateTime.tryParse(map['ultima_verificacion'].toString()) 
          : null,
      estadoConexion: map['estado_conexion']?.toString() ?? 'no_verificado',
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
      'negocio_id': negocioId,
      'servicio': servicio,
      'activo': activo,
      'modo_test': modoTest,
      'publishable_key': publishableKey,
      'secret_key': secretKey,
      'webhook_secret': webhookSecret,
      'api_key': apiKey,
      'configuracion': configuracion,
      'estado_conexion': estadoConexion,
    };
  }

  Map<String, dynamic> toMapForInsert() {
    return {
      'negocio_id': negocioId,
      'servicio': servicio,
      'activo': activo,
      'modo_test': modoTest,
      'publishable_key': publishableKey,
      'secret_key': secretKey,
      'webhook_secret': webhookSecret,
      'api_key': apiKey,
      'configuracion': configuracion,
    };
  }

  /// ¿Está configurado correctamente?
  bool get estaConfigurado {
    switch (servicio) {
      case 'firebase_fcm':
        return apiKey != null && apiKey!.isNotEmpty && activo;
      case 'stripe':
        return secretKey != null && secretKey!.isNotEmpty && activo;
      default:
        return activo;
    }
  }

  /// Obtener nombre legible del servicio
  String get servicioLabel {
    switch (servicio) {
      case 'firebase_fcm':
        return 'Firebase Cloud Messaging';
      case 'stripe':
        return 'Stripe Payments';
      case 'twilio':
        return 'Twilio SMS';
      case 'google_maps':
        return 'Google Maps';
      case 'sendgrid':
        return 'SendGrid Email';
      default:
        return servicio;
    }
  }

  /// Obtener ícono del servicio
  String get servicioIcono {
    switch (servicio) {
      case 'firebase_fcm':
        return '🔔';
      case 'stripe':
        return '💳';
      case 'twilio':
        return '📱';
      case 'google_maps':
        return '🗺️';
      case 'sendgrid':
        return '📧';
      default:
        return '🔌';
    }
  }

  /// Obtener color según estado
  int get estadoColorHex {
    switch (estadoConexion) {
      case 'ok':
        return 0xFF10B981; // Verde
      case 'error':
        return 0xFFEF4444; // Rojo
      default:
        return 0xFFFBBF24; // Amarillo
    }
  }

  ConfiguracionApiModel copyWith({
    String? id,
    String? negocioId,
    String? servicio,
    bool? activo,
    bool? modoTest,
    String? publishableKey,
    String? secretKey,
    String? webhookSecret,
    String? apiKey,
    Map<String, dynamic>? configuracion,
    DateTime? ultimaVerificacion,
    String? estadoConexion,
  }) {
    return ConfiguracionApiModel(
      id: id ?? this.id,
      negocioId: negocioId ?? this.negocioId,
      servicio: servicio ?? this.servicio,
      activo: activo ?? this.activo,
      modoTest: modoTest ?? this.modoTest,
      publishableKey: publishableKey ?? this.publishableKey,
      secretKey: secretKey ?? this.secretKey,
      webhookSecret: webhookSecret ?? this.webhookSecret,
      apiKey: apiKey ?? this.apiKey,
      configuracion: configuracion ?? this.configuracion,
      ultimaVerificacion: ultimaVerificacion ?? this.ultimaVerificacion,
      estadoConexion: estadoConexion ?? this.estadoConexion,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
