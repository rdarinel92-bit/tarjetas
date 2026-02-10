/// ══════════════════════════════════════════════════════════════════════════════
/// DOCUMENTO AVAL MODEL - Robert Darin Fintech V10.26
/// ══════════════════════════════════════════════════════════════════════════════
/// Modelo para documentos subidos por avales (INE, domicilio, etc.)
/// Tabla: documentos_aval
/// ══════════════════════════════════════════════════════════════════════════════

class DocumentoAvalModel {
  final String id;
  final String avalId;
  final String tipo; // ine_frente, ine_reverso, domicilio, selfie, ingresos
  final String url;
  final String? nombreArchivo;
  final int? tamanoBytes;
  final String? mimeType;
  
  // Verificación
  final bool verificado;
  final String? verificadoPor;
  final DateTime? fechaVerificacion;
  final String? notas;
  
  // Timestamps
  final DateTime createdAt;
  final DateTime? updatedAt;

  DocumentoAvalModel({
    required this.id,
    required this.avalId,
    required this.tipo,
    required this.url,
    this.nombreArchivo,
    this.tamanoBytes,
    this.mimeType,
    this.verificado = false,
    this.verificadoPor,
    this.fechaVerificacion,
    this.notas,
    required this.createdAt,
    this.updatedAt,
  });

  factory DocumentoAvalModel.fromMap(Map<String, dynamic> map) {
    return DocumentoAvalModel(
      id: map['id']?.toString() ?? '',
      avalId: map['aval_id']?.toString() ?? '',
      tipo: map['tipo']?.toString() ?? '',
      url: map['url']?.toString() ?? '',
      nombreArchivo: map['nombre_archivo']?.toString(),
      tamanoBytes: map['tamano_bytes'] != null 
          ? int.tryParse(map['tamano_bytes'].toString()) 
          : null,
      mimeType: map['mime_type']?.toString(),
      verificado: map['verificado'] == true,
      verificadoPor: map['verificado_por']?.toString(),
      fechaVerificacion: map['fecha_verificacion'] != null 
          ? DateTime.tryParse(map['fecha_verificacion'].toString()) 
          : null,
      notas: map['notas']?.toString(),
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: map['updated_at'] != null 
          ? DateTime.tryParse(map['updated_at'].toString()) 
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'aval_id': avalId,
      'tipo': tipo,
      'url': url,
      'nombre_archivo': nombreArchivo,
      'tamano_bytes': tamanoBytes,
      'mime_type': mimeType,
      'verificado': verificado,
      'verificado_por': verificadoPor,
      'fecha_verificacion': fechaVerificacion?.toIso8601String(),
      'notas': notas,
    };
  }

  Map<String, dynamic> toMapForInsert() {
    return {
      'aval_id': avalId,
      'tipo': tipo,
      'url': url,
      'nombre_archivo': nombreArchivo,
      'tamano_bytes': tamanoBytes,
      'mime_type': mimeType,
    };
  }

  /// Obtener etiqueta legible del tipo
  String get tipoLabel {
    switch (tipo) {
      case 'ine_frente':
        return 'INE (Frente)';
      case 'ine_reverso':
        return 'INE (Reverso)';
      case 'domicilio':
        return 'Comprobante de Domicilio';
      case 'selfie':
        return 'Selfie de Verificación';
      case 'ingresos':
        return 'Comprobante de Ingresos';
      default:
        return tipo;
    }
  }

  /// Obtener ícono para el tipo
  String get tipoIcono {
    switch (tipo) {
      case 'ine_frente':
      case 'ine_reverso':
        return '🪪';
      case 'domicilio':
        return '🏠';
      case 'selfie':
        return '🤳';
      case 'ingresos':
        return '💰';
      default:
        return '📄';
    }
  }

  DocumentoAvalModel copyWith({
    String? id,
    String? avalId,
    String? tipo,
    String? url,
    String? nombreArchivo,
    int? tamanoBytes,
    String? mimeType,
    bool? verificado,
    String? verificadoPor,
    DateTime? fechaVerificacion,
    String? notas,
  }) {
    return DocumentoAvalModel(
      id: id ?? this.id,
      avalId: avalId ?? this.avalId,
      tipo: tipo ?? this.tipo,
      url: url ?? this.url,
      nombreArchivo: nombreArchivo ?? this.nombreArchivo,
      tamanoBytes: tamanoBytes ?? this.tamanoBytes,
      mimeType: mimeType ?? this.mimeType,
      verificado: verificado ?? this.verificado,
      verificadoPor: verificadoPor ?? this.verificadoPor,
      fechaVerificacion: fechaVerificacion ?? this.fechaVerificacion,
      notas: notas ?? this.notas,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
