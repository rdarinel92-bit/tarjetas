/// Modelo para la tabla `notificaciones` de Supabase
/// Representa una notificación para un usuario
class NotificacionModel {
  final String id;
  final String usuarioId;
  final String titulo;
  final String mensaje;
  final String tipo; // info, warning, success, error, pago, cobranza, promocion, sistema
  final bool leida;
  final DateTime? fechaLectura;
  final String? enlace;
  final String? rutaDestino;
  final String? notificacionMasivaId;
  final DateTime createdAt;

  NotificacionModel({
    required this.id,
    required this.usuarioId,
    required this.titulo,
    required this.mensaje,
    this.tipo = 'info',
    this.leida = false,
    this.fechaLectura,
    this.enlace,
    this.rutaDestino,
    this.notificacionMasivaId,
    required this.createdAt,
  });

  /// Icono según el tipo de notificación
  String get icono {
    switch (tipo) {
      case 'success':
        return '✅';
      case 'warning':
        return '⚠️';
      case 'error':
        return '❌';
      case 'pago':
        return '💰';
      case 'cobranza':
        return '📋';
      case 'promocion':
        return '🎉';
      case 'sistema':
        return '⚙️';
      default:
        return 'ℹ️';
    }
  }

  /// Tiempo relativo desde que se creó
  String get tiempoRelativo {
    final ahora = DateTime.now();
    final diferencia = ahora.difference(createdAt);

    if (diferencia.inMinutes < 1) {
      return 'Ahora';
    } else if (diferencia.inMinutes < 60) {
      return 'Hace ${diferencia.inMinutes} min';
    } else if (diferencia.inHours < 24) {
      return 'Hace ${diferencia.inHours} h';
    } else if (diferencia.inDays < 7) {
      return 'Hace ${diferencia.inDays} días';
    } else {
      return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
    }
  }

  factory NotificacionModel.fromMap(Map<String, dynamic> map) {
    return NotificacionModel(
      id: map['id'] ?? '',
      usuarioId: map['usuario_id'] ?? '',
      titulo: map['titulo'] ?? '',
      mensaje: map['mensaje'] ?? '',
      tipo: map['tipo'] ?? 'info',
      leida: map['leida'] ?? false,
      fechaLectura: map['fecha_lectura'] != null ? DateTime.parse(map['fecha_lectura']) : null,
      enlace: map['enlace'],
      rutaDestino: map['ruta_destino'],
      notificacionMasivaId: map['notificacion_masiva_id'],
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'usuario_id': usuarioId,
    'titulo': titulo,
    'mensaje': mensaje,
    'tipo': tipo,
    'leida': leida,
    'fecha_lectura': fechaLectura?.toIso8601String(),
    'enlace': enlace,
    'ruta_destino': rutaDestino,
    'notificacion_masiva_id': notificacionMasivaId,
  };

  Map<String, dynamic> toMapForInsert() => {
    'usuario_id': usuarioId,
    'titulo': titulo,
    'mensaje': mensaje,
    'tipo': tipo,
    'leida': leida,
    'enlace': enlace,
    'ruta_destino': rutaDestino,
    'notificacion_masiva_id': notificacionMasivaId,
  };

  NotificacionModel copyWith({
    String? id,
    String? usuarioId,
    String? titulo,
    String? mensaje,
    String? tipo,
    bool? leida,
    DateTime? fechaLectura,
    String? enlace,
    String? rutaDestino,
    String? notificacionMasivaId,
    DateTime? createdAt,
  }) {
    return NotificacionModel(
      id: id ?? this.id,
      usuarioId: usuarioId ?? this.usuarioId,
      titulo: titulo ?? this.titulo,
      mensaje: mensaje ?? this.mensaje,
      tipo: tipo ?? this.tipo,
      leida: leida ?? this.leida,
      fechaLectura: fechaLectura ?? this.fechaLectura,
      enlace: enlace ?? this.enlace,
      rutaDestino: rutaDestino ?? this.rutaDestino,
      notificacionMasivaId: notificacionMasivaId ?? this.notificacionMasivaId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() => 'NotificacionModel(id: $id, titulo: $titulo, leida: $leida)';
}

/// Modelo para notificaciones masivas (enviadas por admin)
class NotificacionMasivaModel {
  final String id;
  final String titulo;
  final String mensaje;
  final String tipo; // anuncio, tanda, prestamo, promocion, aviso
  final String? rutaDestino;
  final String? imagenUrl;
  final String audiencia; // todos, cliente, empleado, aval
  final int destinatariosCount;
  final int leidosCount;
  final String? enviadoPor;
  final DateTime createdAt;

  NotificacionMasivaModel({
    required this.id,
    required this.titulo,
    required this.mensaje,
    this.tipo = 'anuncio',
    this.rutaDestino,
    this.imagenUrl,
    this.audiencia = 'todos',
    this.destinatariosCount = 0,
    this.leidosCount = 0,
    this.enviadoPor,
    required this.createdAt,
  });

  /// Porcentaje de lectura
  double get porcentajeLectura {
    if (destinatariosCount == 0) return 0;
    return (leidosCount / destinatariosCount) * 100;
  }

  factory NotificacionMasivaModel.fromMap(Map<String, dynamic> map) {
    return NotificacionMasivaModel(
      id: map['id'] ?? '',
      titulo: map['titulo'] ?? '',
      mensaje: map['mensaje'] ?? '',
      tipo: map['tipo'] ?? 'anuncio',
      rutaDestino: map['ruta_destino'],
      imagenUrl: map['imagen_url'],
      audiencia: map['audiencia'] ?? 'todos',
      destinatariosCount: map['destinatarios_count'] ?? 0,
      leidosCount: map['leidos_count'] ?? 0,
      enviadoPor: map['enviado_por'],
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'titulo': titulo,
    'mensaje': mensaje,
    'tipo': tipo,
    'ruta_destino': rutaDestino,
    'imagen_url': imagenUrl,
    'audiencia': audiencia,
    'destinatarios_count': destinatariosCount,
    'leidos_count': leidosCount,
    'enviado_por': enviadoPor,
  };

  Map<String, dynamic> toMapForInsert() => {
    'titulo': titulo,
    'mensaje': mensaje,
    'tipo': tipo,
    'ruta_destino': rutaDestino,
    'imagen_url': imagenUrl,
    'audiencia': audiencia,
    'enviado_por': enviadoPor,
  };

  @override
  String toString() => 'NotificacionMasivaModel(id: $id, titulo: $titulo, audiencia: $audiencia)';
}
