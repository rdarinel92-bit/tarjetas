/// ══════════════════════════════════════════════════════════════════════════════
/// AVAL CHECKIN MODEL - Robert Darin Fintech V10.26
/// ══════════════════════════════════════════════════════════════════════════════
/// Modelo para registro de ubicación voluntaria de avales
/// Tabla: aval_checkins
/// ══════════════════════════════════════════════════════════════════════════════

class AvalCheckinModel {
  final String id;
  final String avalId;
  final double latitud;
  final double longitud;
  final double? precisionMetros;
  final String? direccionAproximada;
  final String? ipAddress;
  final String? userAgent;
  final String motivo; // voluntario, solicitado, automatico
  final DateTime fecha;

  AvalCheckinModel({
    required this.id,
    required this.avalId,
    required this.latitud,
    required this.longitud,
    this.precisionMetros,
    this.direccionAproximada,
    this.ipAddress,
    this.userAgent,
    this.motivo = 'voluntario',
    required this.fecha,
  });

  factory AvalCheckinModel.fromMap(Map<String, dynamic> map) {
    return AvalCheckinModel(
      id: map['id']?.toString() ?? '',
      avalId: map['aval_id']?.toString() ?? '',
      latitud: double.tryParse(map['latitud']?.toString() ?? '0') ?? 0,
      longitud: double.tryParse(map['longitud']?.toString() ?? '0') ?? 0,
      precisionMetros: map['precision_metros'] != null 
          ? double.tryParse(map['precision_metros'].toString()) 
          : null,
      direccionAproximada: map['direccion_aproximada']?.toString(),
      ipAddress: map['ip_address']?.toString(),
      userAgent: map['user_agent']?.toString(),
      motivo: map['motivo']?.toString() ?? 'voluntario',
      fecha: DateTime.tryParse(map['fecha']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'aval_id': avalId,
      'latitud': latitud,
      'longitud': longitud,
      'precision_metros': precisionMetros,
      'direccion_aproximada': direccionAproximada,
      'ip_address': ipAddress,
      'user_agent': userAgent,
      'motivo': motivo,
    };
  }

  Map<String, dynamic> toMapForInsert() {
    return {
      'aval_id': avalId,
      'latitud': latitud,
      'longitud': longitud,
      'precision_metros': precisionMetros,
      'direccion_aproximada': direccionAproximada,
      'ip_address': ipAddress,
      'user_agent': userAgent,
      'motivo': motivo,
    };
  }

  /// Generar URL de Google Maps
  String get googleMapsUrl => 
      'https://www.google.com/maps?q=$latitud,$longitud';

  /// Verificar si la precisión es buena (menos de 50 metros)
  bool get precisionBuena => 
      precisionMetros != null && precisionMetros! < 50;

  /// Obtener etiqueta del motivo
  String get motivoLabel {
    switch (motivo) {
      case 'voluntario':
        return 'Check-in voluntario';
      case 'solicitado':
        return 'Solicitado por admin';
      case 'automatico':
        return 'Automático';
      default:
        return motivo;
    }
  }
}
