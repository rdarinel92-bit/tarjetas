/// ══════════════════════════════════════════════════════════════════════════════
/// NOTIFICACIÓN DOCUMENTO AVAL MODEL - Robert Darin Fintech V10.26
/// ══════════════════════════════════════════════════════════════════════════════
/// Modelo para notificaciones cuando se aprueban/rechazan documentos de avales
/// Tabla: notificaciones_documento_aval
/// ══════════════════════════════════════════════════════════════════════════════

class NotificacionDocumentoAvalModel {
  final String id;
  final String avalId;
  final String? documentoId;
  final String tipoDocumento;
  final String tipoNotificacion; // aprobado, rechazado, pendiente_revision
  final String mensaje;
  final String? motivoRechazo;
  final bool leida;
  final DateTime? fechaLectura;
  final bool enviadaPush;
  final DateTime? fechaEnvioPush;
  final String? creadoPor;
  final DateTime createdAt;

  NotificacionDocumentoAvalModel({
    required this.id,
    required this.avalId,
    this.documentoId,
    required this.tipoDocumento,
    required this.tipoNotificacion,
    required this.mensaje,
    this.motivoRechazo,
    this.leida = false,
    this.fechaLectura,
    this.enviadaPush = false,
    this.fechaEnvioPush,
    this.creadoPor,
    required this.createdAt,
  });

  factory NotificacionDocumentoAvalModel.fromMap(Map<String, dynamic> map) {
    return NotificacionDocumentoAvalModel(
      id: map['id']?.toString() ?? '',
      avalId: map['aval_id']?.toString() ?? '',
      documentoId: map['documento_id']?.toString(),
      tipoDocumento: map['tipo_documento']?.toString() ?? '',
      tipoNotificacion: map['tipo_notificacion']?.toString() ?? '',
      mensaje: map['mensaje']?.toString() ?? '',
      motivoRechazo: map['motivo_rechazo']?.toString(),
      leida: map['leida'] == true,
      fechaLectura: map['fecha_lectura'] != null 
          ? DateTime.tryParse(map['fecha_lectura'].toString()) 
          : null,
      enviadaPush: map['enviada_push'] == true,
      fechaEnvioPush: map['fecha_envio_push'] != null 
          ? DateTime.tryParse(map['fecha_envio_push'].toString()) 
          : null,
      creadoPor: map['creado_por']?.toString(),
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'aval_id': avalId,
      'documento_id': documentoId,
      'tipo_documento': tipoDocumento,
      'tipo_notificacion': tipoNotificacion,
      'mensaje': mensaje,
      'motivo_rechazo': motivoRechazo,
      'leida': leida,
      'fecha_lectura': fechaLectura?.toIso8601String(),
      'enviada_push': enviadaPush,
      'fecha_envio_push': fechaEnvioPush?.toIso8601String(),
      'creado_por': creadoPor,
    };
  }

  Map<String, dynamic> toMapForInsert() {
    return {
      'aval_id': avalId,
      'documento_id': documentoId,
      'tipo_documento': tipoDocumento,
      'tipo_notificacion': tipoNotificacion,
      'mensaje': mensaje,
      'motivo_rechazo': motivoRechazo,
      'creado_por': creadoPor,
    };
  }

  /// ¿Es aprobación?
  bool get esAprobacion => tipoNotificacion == 'aprobado';

  /// ¿Es rechazo?
  bool get esRechazo => tipoNotificacion == 'rechazado';

  /// Obtener ícono según tipo
  String get icono {
    switch (tipoNotificacion) {
      case 'aprobado':
        return '✅';
      case 'rechazado':
        return '❌';
      case 'pendiente_revision':
        return '⏳';
      default:
        return '📋';
    }
  }

  /// Obtener color según tipo (código hex)
  int get colorHex {
    switch (tipoNotificacion) {
      case 'aprobado':
        return 0xFF10B981; // Verde
      case 'rechazado':
        return 0xFFEF4444; // Rojo
      case 'pendiente_revision':
        return 0xFFFBBF24; // Amarillo
      default:
        return 0xFF6B7280; // Gris
    }
  }
}
