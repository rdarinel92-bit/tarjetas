/// Modelo para propiedades/terrenos que el dueño está comprando
class PropiedadModel {
  final String id;
  final String nombre;
  final String tipo; // terreno, casa, local, departamento, otro
  final String? descripcion;
  final String? ubicacion;
  final double? superficieM2;
  
  // Financiero
  final double precioTotal;
  final double enganche;
  final double saldoInicial;
  final double montoMensual;
  final String frecuenciaPago;
  final int diaPago;
  final int? plazoMeses;
  
  // Fechas
  final DateTime? fechaCompra;
  final DateTime? fechaInicioPagos;
  final DateTime? fechaFinEstimada;
  
  // Vendedor
  final String? vendedorNombre;
  final String? vendedorTelefono;
  final String? vendedorCuentaBanco;
  final String? vendedorBanco;
  
  // Asignación
  final String? asignadoA;
  final String? asignadoNombre; // Join con usuarios
  
  // Estado
  final String estado;
  final String? notas;
  final DateTime createdAt;

  PropiedadModel({
    required this.id,
    required this.nombre,
    this.tipo = 'terreno',
    this.descripcion,
    this.ubicacion,
    this.superficieM2,
    required this.precioTotal,
    this.enganche = 0,
    required this.saldoInicial,
    required this.montoMensual,
    this.frecuenciaPago = 'Mensual',
    this.diaPago = 15,
    this.plazoMeses,
    this.fechaCompra,
    this.fechaInicioPagos,
    this.fechaFinEstimada,
    this.vendedorNombre,
    this.vendedorTelefono,
    this.vendedorCuentaBanco,
    this.vendedorBanco,
    this.asignadoA,
    this.asignadoNombre,
    this.estado = 'en_pagos',
    this.notas,
    required this.createdAt,
  });

  factory PropiedadModel.fromMap(Map<String, dynamic> map) {
    return PropiedadModel(
      id: map['id'],
      nombre: map['nombre'] ?? '',
      tipo: map['tipo'] ?? 'terreno',
      descripcion: map['descripcion'],
      ubicacion: map['ubicacion'],
      superficieM2: map['superficie_m2']?.toDouble(),
      precioTotal: (map['precio_total'] as num?)?.toDouble() ?? 0,
      enganche: (map['enganche'] as num?)?.toDouble() ?? 0,
      saldoInicial: (map['saldo_inicial'] as num?)?.toDouble() ?? 0,
      montoMensual: (map['monto_mensual'] as num?)?.toDouble() ?? 0,
      frecuenciaPago: map['frecuencia_pago'] ?? 'Mensual',
      diaPago: map['dia_pago'] ?? 15,
      plazoMeses: map['plazo_meses'],
      fechaCompra: map['fecha_compra'] != null ? DateTime.parse(map['fecha_compra']) : null,
      fechaInicioPagos: map['fecha_inicio_pagos'] != null ? DateTime.parse(map['fecha_inicio_pagos']) : null,
      fechaFinEstimada: map['fecha_fin_estimada'] != null ? DateTime.parse(map['fecha_fin_estimada']) : null,
      vendedorNombre: map['vendedor_nombre'],
      vendedorTelefono: map['vendedor_telefono'],
      vendedorCuentaBanco: map['vendedor_cuenta_banco'],
      vendedorBanco: map['vendedor_banco'],
      asignadoA: map['asignado_a'],
      asignadoNombre: map['usuarios']?['nombre_completo'],
      estado: map['estado'] ?? 'en_pagos',
      notas: map['notas'],
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toMapForInsert() {
    return {
      'nombre': nombre,
      'tipo': tipo,
      'descripcion': descripcion,
      'ubicacion': ubicacion,
      'superficie_m2': superficieM2,
      'precio_total': precioTotal,
      'enganche': enganche,
      'saldo_inicial': saldoInicial,
      'monto_mensual': montoMensual,
      'frecuencia_pago': frecuenciaPago,
      'dia_pago': diaPago,
      'plazo_meses': plazoMeses,
      'fecha_compra': fechaCompra?.toIso8601String().split('T')[0],
      'fecha_inicio_pagos': fechaInicioPagos?.toIso8601String().split('T')[0],
      'fecha_fin_estimada': fechaFinEstimada?.toIso8601String().split('T')[0],
      'vendedor_nombre': vendedorNombre,
      'vendedor_telefono': vendedorTelefono,
      'vendedor_cuenta_banco': vendedorCuentaBanco,
      'vendedor_banco': vendedorBanco,
      'asignado_a': asignadoA,
      'estado': estado,
      'notas': notas,
    };
  }

  /// Calcula el saldo pendiente basado en los pagos realizados
  double calcularSaldoPendiente(double totalPagado) {
    return saldoInicial - totalPagado;
  }

  /// Helper para obtener nombre del tipo
  String get tipoNombre {
    switch (tipo) {
      case 'terreno': return 'Terreno';
      case 'casa': return 'Casa';
      case 'local': return 'Local Comercial';
      case 'departamento': return 'Departamento';
      default: return 'Propiedad';
    }
  }

  /// Helper para icono del tipo
  String get tipoEmoji {
    switch (tipo) {
      case 'terreno': return '🏞️';
      case 'casa': return '🏠';
      case 'local': return '🏪';
      case 'departamento': return '🏢';
      default: return '📍';
    }
  }
}

/// Modelo para pagos de propiedades
class PagoPropiedadModel {
  final String id;
  final String propiedadId;
  final int numeroPago;
  final double monto;
  final DateTime fechaProgramada;
  final DateTime? fechaPago;
  final String? pagadoPor;
  final String? pagadoPorNombre;
  final String? metodoPago;
  final String? referencia;
  final String? comprobanteUrl;
  final String? comprobanteFilename;
  final String estado;
  final String? notas;
  final DateTime createdAt;

  PagoPropiedadModel({
    required this.id,
    required this.propiedadId,
    required this.numeroPago,
    required this.monto,
    required this.fechaProgramada,
    this.fechaPago,
    this.pagadoPor,
    this.pagadoPorNombre,
    this.metodoPago,
    this.referencia,
    this.comprobanteUrl,
    this.comprobanteFilename,
    this.estado = 'pendiente',
    this.notas,
    required this.createdAt,
  });

  factory PagoPropiedadModel.fromMap(Map<String, dynamic> map) {
    return PagoPropiedadModel(
      id: map['id'],
      propiedadId: map['propiedad_id'],
      numeroPago: map['numero_pago'] ?? 0,
      monto: (map['monto'] as num?)?.toDouble() ?? 0,
      fechaProgramada: DateTime.parse(map['fecha_programada']),
      fechaPago: map['fecha_pago'] != null ? DateTime.parse(map['fecha_pago']) : null,
      pagadoPor: map['pagado_por'],
      pagadoPorNombre: map['usuarios']?['nombre_completo'],
      metodoPago: map['metodo_pago'],
      referencia: map['referencia'],
      comprobanteUrl: map['comprobante_url'],
      comprobanteFilename: map['comprobante_filename'],
      estado: map['estado'] ?? 'pendiente',
      notas: map['notas'],
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toMapForInsert() {
    return {
      'propiedad_id': propiedadId,
      'numero_pago': numeroPago,
      'monto': monto,
      'fecha_programada': fechaProgramada.toIso8601String().split('T')[0],
      'fecha_pago': fechaPago?.toIso8601String().split('T')[0],
      'pagado_por': pagadoPor,
      'metodo_pago': metodoPago,
      'referencia': referencia,
      'comprobante_url': comprobanteUrl,
      'comprobante_filename': comprobanteFilename,
      'estado': estado,
      'notas': notas,
    };
  }

  /// Check if payment is overdue
  bool get estaAtrasado {
    if (estado == 'pagado') return false;
    return DateTime.now().isAfter(fechaProgramada);
  }

  /// Days until due or overdue
  int get diasParaVencer {
    return fechaProgramada.difference(DateTime.now()).inDays;
  }
}
