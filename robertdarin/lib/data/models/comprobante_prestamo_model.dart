class ComprobantePrestamoModel {
  final String id;
  final String prestamoId;
  final String tipo;
  final String url;
  final double? latitud;
  final double? longitud;
  final DateTime createdAt;

  ComprobantePrestamoModel({
    required this.id,
    required this.prestamoId,
    required this.tipo,
    required this.url,
    required this.latitud,
    required this.longitud,
    required this.createdAt,
  });

  factory ComprobantePrestamoModel.fromMap(Map<String, dynamic> map) {
    return ComprobantePrestamoModel(
      id: map['id'],
      prestamoId: map['prestamo_id'],
      tipo: map['tipo'],
      url: map['url'],
      latitud: map['latitud'] != null ? (map['latitud'] as num).toDouble() : null,
      longitud: map['longitud'] != null ? (map['longitud'] as num).toDouble() : null,
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'prestamo_id': prestamoId,
      'tipo': tipo,
      'url': url,
      'latitud': latitud,
      'longitud': longitud,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
