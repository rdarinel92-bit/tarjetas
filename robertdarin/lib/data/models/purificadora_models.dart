/// ═══════════════════════════════════════════════════════════════════════════════
/// MODELOS DEL MÓDULO PURIFICADORA - Robert Darin Platform
/// ═══════════════════════════════════════════════════════════════════════════════

// Cliente de Purificadora
class PurificadoraClienteModel {
  final String id;
  final String? negocioId;
  final String? codigoCliente;
  final String nombre;
  final String? telefono;
  final String? whatsapp;
  final String direccion;
  final String? colonia;
  final String? referencias;
  final String? coordenadas;
  final String tipoCliente;
  final int garrafonesEnPrestamo;
  final int garrafonesMaximo;
  final String frecuenciaEntrega;
  final List<String> diasEntrega;
  final double saldoPendiente;
  final DateTime? ultimaEntrega;
  final String? notas;
  final bool activo;
  final DateTime? createdAt;

  PurificadoraClienteModel({
    required this.id,
    this.negocioId,
    this.codigoCliente,
    required this.nombre,
    this.telefono,
    this.whatsapp,
    required this.direccion,
    this.colonia,
    this.referencias,
    this.coordenadas,
    this.tipoCliente = 'casa',
    this.garrafonesEnPrestamo = 0,
    this.garrafonesMaximo = 5,
    this.frecuenciaEntrega = 'semanal',
    this.diasEntrega = const [],
    this.saldoPendiente = 0,
    this.ultimaEntrega,
    this.notas,
    this.activo = true,
    this.createdAt,
  });

  factory PurificadoraClienteModel.fromMap(Map<String, dynamic> map) {
    return PurificadoraClienteModel(
      id: map['id'] ?? '',
      negocioId: map['negocio_id'],
      codigoCliente: map['codigo_cliente'],
      nombre: map['nombre'] ?? '',
      telefono: map['telefono'],
      whatsapp: map['whatsapp'],
      direccion: map['direccion'] ?? '',
      colonia: map['colonia'],
      referencias: map['referencias'],
      coordenadas: map['coordenadas'],
      tipoCliente: map['tipo_cliente'] ?? 'casa',
      garrafonesEnPrestamo: map['garrafones_en_prestamo'] ?? 0,
      garrafonesMaximo: map['garrafones_maximo'] ?? 5,
      frecuenciaEntrega: map['frecuencia_entrega'] ?? 'semanal',
      diasEntrega: map['dias_entrega'] != null ? List<String>.from(map['dias_entrega']) : [],
      saldoPendiente: (map['saldo_pendiente'] ?? 0).toDouble(),
      ultimaEntrega: map['ultima_entrega'] != null ? DateTime.parse(map['ultima_entrega']) : null,
      notas: map['notas'],
      activo: map['activo'] ?? true,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
    );
  }

  Map<String, dynamic> toMapForInsert() => {
    'negocio_id': negocioId,
    'codigo_cliente': codigoCliente,
    'nombre': nombre,
    'telefono': telefono,
    'whatsapp': whatsapp,
    'direccion': direccion,
    'colonia': colonia,
    'referencias': referencias,
    'coordenadas': coordenadas,
    'tipo_cliente': tipoCliente,
    'garrafones_en_prestamo': garrafonesEnPrestamo,
    'garrafones_maximo': garrafonesMaximo,
    'frecuencia_entrega': frecuenciaEntrega,
    'dias_entrega': diasEntrega,
    'notas': notas,
    'activo': activo,
  };

  String get tipoDisplay {
    switch (tipoCliente) {
      case 'casa': return '🏠 Casa';
      case 'negocio': return '🏪 Negocio';
      case 'oficina': return '🏢 Oficina';
      case 'escuela': return '🏫 Escuela';
      case 'restaurante': return '🍽️ Restaurante';
      default: return tipoCliente;
    }
  }
}

// Repartidor
class PurificadoraRepartidorModel {
  final String id;
  final String? negocioId;
  final String? usuarioId;
  final String nombre;
  final String? telefono;
  final String? licencia;
  final String? vehiculo;
  final String? placas;
  final int garrafonesAsignados;
  final String estado;
  final bool activo;
  final DateTime? createdAt;

  PurificadoraRepartidorModel({
    required this.id,
    this.negocioId,
    this.usuarioId,
    required this.nombre,
    this.telefono,
    this.licencia,
    this.vehiculo,
    this.placas,
    this.garrafonesAsignados = 0,
    this.estado = 'disponible',
    this.activo = true,
    this.createdAt,
  });

  factory PurificadoraRepartidorModel.fromMap(Map<String, dynamic> map) {
    return PurificadoraRepartidorModel(
      id: map['id'] ?? '',
      negocioId: map['negocio_id'],
      usuarioId: map['usuario_id'],
      nombre: map['nombre'] ?? '',
      telefono: map['telefono'],
      licencia: map['licencia'],
      vehiculo: map['vehiculo'],
      placas: map['placas'],
      garrafonesAsignados: map['garrafones_asignados'] ?? 0,
      estado: map['estado'] ?? 'disponible',
      activo: map['activo'] ?? true,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
    );
  }

  Map<String, dynamic> toMapForInsert() => {
    'negocio_id': negocioId,
    'usuario_id': usuarioId,
    'nombre': nombre,
    'telefono': telefono,
    'licencia': licencia,
    'vehiculo': vehiculo,
    'placas': placas,
    'activo': activo,
  };

  String get estadoDisplay {
    switch (estado) {
      case 'disponible': return '🟢 Disponible';
      case 'en_ruta': return '🚚 En Ruta';
      case 'descansando': return '☕ Descansando';
      case 'inactivo': return '⚪ Inactivo';
      default: return estado;
    }
  }
}

// Ruta
class PurificadoraRutaModel {
  final String id;
  final String? negocioId;
  final String nombre;
  final String? descripcion;
  final String? repartidorId;
  final List<String> diasRuta;
  final String horarioInicio;
  final String horarioFin;
  final int clientesTotal;
  final String? zonaCoordenadas;
  final bool activo;
  final DateTime? createdAt;
  
  // Relación
  final String? repartidorNombre;

  PurificadoraRutaModel({
    required this.id,
    this.negocioId,
    required this.nombre,
    this.descripcion,
    this.repartidorId,
    this.diasRuta = const [],
    this.horarioInicio = '07:00',
    this.horarioFin = '15:00',
    this.clientesTotal = 0,
    this.zonaCoordenadas,
    this.activo = true,
    this.createdAt,
    this.repartidorNombre,
  });

  factory PurificadoraRutaModel.fromMap(Map<String, dynamic> map) {
    return PurificadoraRutaModel(
      id: map['id'] ?? '',
      negocioId: map['negocio_id'],
      nombre: map['nombre'] ?? '',
      descripcion: map['descripcion'],
      repartidorId: map['repartidor_id'],
      diasRuta: map['dias_ruta'] != null ? List<String>.from(map['dias_ruta']) : [],
      horarioInicio: map['horario_inicio'] ?? '07:00',
      horarioFin: map['horario_fin'] ?? '15:00',
      clientesTotal: map['clientes_total'] ?? 0,
      zonaCoordenadas: map['zona_coordenadas'],
      activo: map['activo'] ?? true,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
      repartidorNombre: map['purificadora_repartidores']?['nombre'],
    );
  }

  Map<String, dynamic> toMapForInsert() => {
    'negocio_id': negocioId,
    'nombre': nombre,
    'descripcion': descripcion,
    'repartidor_id': repartidorId,
    'dias_ruta': diasRuta,
    'horario_inicio': horarioInicio,
    'horario_fin': horarioFin,
    'activo': activo,
  };
}

// Producción
class PurificadoraProduccionModel {
  final String id;
  final String? negocioId;
  final DateTime fecha;
  final int garrafonesProducidos;
  final int garrafonesDefectuosos;
  final double litrosUtilizados;
  final String? lote;
  final String turno;
  final String? operador;
  final String? notas;
  final DateTime? createdAt;

  PurificadoraProduccionModel({
    required this.id,
    this.negocioId,
    required this.fecha,
    this.garrafonesProducidos = 0,
    this.garrafonesDefectuosos = 0,
    this.litrosUtilizados = 0,
    this.lote,
    this.turno = 'matutino',
    this.operador,
    this.notas,
    this.createdAt,
  });

  factory PurificadoraProduccionModel.fromMap(Map<String, dynamic> map) {
    return PurificadoraProduccionModel(
      id: map['id'] ?? '',
      negocioId: map['negocio_id'],
      fecha: DateTime.parse(map['fecha'] ?? DateTime.now().toIso8601String()),
      garrafonesProducidos: map['garrafones_producidos'] ?? 0,
      garrafonesDefectuosos: map['garrafones_defectuosos'] ?? 0,
      litrosUtilizados: (map['litros_utilizados'] ?? 0).toDouble(),
      lote: map['lote'],
      turno: map['turno'] ?? 'matutino',
      operador: map['operador'],
      notas: map['notas'],
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
    );
  }

  Map<String, dynamic> toMapForInsert() => {
    'negocio_id': negocioId,
    'fecha': fecha.toIso8601String().split('T')[0],
    'garrafones_producidos': garrafonesProducidos,
    'garrafones_defectuosos': garrafonesDefectuosos,
    'litros_utilizados': litrosUtilizados,
    'lote': lote,
    'turno': turno,
    'operador': operador,
    'notas': notas,
  };

  int get garrafonesBuenos => garrafonesProducidos - garrafonesDefectuosos;
  double get porcentajeEficiencia => garrafonesProducidos > 0 
      ? (garrafonesBuenos / garrafonesProducidos) * 100 
      : 0;
}

// Entrega
class PurificadoraEntregaModel {
  final String id;
  final String? negocioId;
  final String? rutaId;
  final String? repartidorId;
  final String? clienteId;
  final DateTime fecha;
  final int garrafonesEntregados;
  final int garrafonesRecogidos;
  final double monto;
  final bool pagado;
  final String? metodoPago;
  final String estado;
  final String? notas;
  final String? coordenadasEntrega;
  final DateTime? horaEntrega;
  final DateTime? createdAt;
  
  // Relaciones
  final String? clienteNombre;
  final String? clienteDireccion;
  final String? repartidorNombre;
  final String? rutaNombre;

  PurificadoraEntregaModel({
    required this.id,
    this.negocioId,
    this.rutaId,
    this.repartidorId,
    this.clienteId,
    required this.fecha,
    this.garrafonesEntregados = 0,
    this.garrafonesRecogidos = 0,
    this.monto = 0,
    this.pagado = false,
    this.metodoPago,
    this.estado = 'pendiente',
    this.notas,
    this.coordenadasEntrega,
    this.horaEntrega,
    this.createdAt,
    this.clienteNombre,
    this.clienteDireccion,
    this.repartidorNombre,
    this.rutaNombre,
  });

  factory PurificadoraEntregaModel.fromMap(Map<String, dynamic> map) {
    return PurificadoraEntregaModel(
      id: map['id'] ?? '',
      negocioId: map['negocio_id'],
      rutaId: map['ruta_id'],
      repartidorId: map['repartidor_id'],
      clienteId: map['cliente_id'],
      fecha: DateTime.parse(map['fecha'] ?? DateTime.now().toIso8601String()),
      garrafonesEntregados: map['garrafones_entregados'] ?? 0,
      garrafonesRecogidos: map['garrafones_recogidos'] ?? 0,
      monto: (map['monto'] ?? 0).toDouble(),
      pagado: map['pagado'] ?? false,
      metodoPago: map['metodo_pago'],
      estado: map['estado'] ?? 'pendiente',
      notas: map['notas'],
      coordenadasEntrega: map['coordenadas_entrega'],
      horaEntrega: map['hora_entrega'] != null ? DateTime.parse(map['hora_entrega']) : null,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
      clienteNombre: map['purificadora_clientes']?['nombre'],
      clienteDireccion: map['purificadora_clientes']?['direccion'],
      repartidorNombre: map['purificadora_repartidores']?['nombre'],
      rutaNombre: map['purificadora_rutas']?['nombre'],
    );
  }

  Map<String, dynamic> toMapForInsert() => {
    'negocio_id': negocioId,
    'ruta_id': rutaId,
    'repartidor_id': repartidorId,
    'cliente_id': clienteId,
    'fecha': fecha.toIso8601String().split('T')[0],
    'garrafones_entregados': garrafonesEntregados,
    'garrafones_recogidos': garrafonesRecogidos,
    'monto': monto,
    'pagado': pagado,
    'metodo_pago': metodoPago,
    'estado': estado,
    'notas': notas,
  };

  String get estadoDisplay {
    switch (estado) {
      case 'pendiente': return '⏳ Pendiente';
      case 'en_camino': return '🚚 En Camino';
      case 'entregado': return '✅ Entregado';
      case 'no_entregado': return '❌ No Entregado';
      case 'reagendado': return '📅 Reagendado';
      default: return estado;
    }
  }

  int get diferencia => garrafonesEntregados - garrafonesRecogidos;
}

// Corte de Ruta
class PurificadoraCorteRutaModel {
  final String id;
  final String? negocioId;
  final String? rutaId;
  final String? repartidorId;
  final DateTime fecha;
  final int garrafonesSalida;
  final int garrafonesVendidos;
  final int garrafonesRegreso;
  final int garrafonesFaltantes;
  final double totalVentas;
  final double totalCobranzaAnterior;
  final double efectivoRecibido;
  final double transferenciasRecibidas;
  final double diferencia;
  final String estado;
  final String? observaciones;
  final DateTime? createdAt;
  
  // Relaciones
  final String? rutaNombre;
  final String? repartidorNombre;

  PurificadoraCorteRutaModel({
    required this.id,
    this.negocioId,
    this.rutaId,
    this.repartidorId,
    required this.fecha,
    this.garrafonesSalida = 0,
    this.garrafonesVendidos = 0,
    this.garrafonesRegreso = 0,
    this.garrafonesFaltantes = 0,
    this.totalVentas = 0,
    this.totalCobranzaAnterior = 0,
    this.efectivoRecibido = 0,
    this.transferenciasRecibidas = 0,
    this.diferencia = 0,
    this.estado = 'abierto',
    this.observaciones,
    this.createdAt,
    this.rutaNombre,
    this.repartidorNombre,
  });

  factory PurificadoraCorteRutaModel.fromMap(Map<String, dynamic> map) {
    return PurificadoraCorteRutaModel(
      id: map['id'] ?? '',
      negocioId: map['negocio_id'],
      rutaId: map['ruta_id'],
      repartidorId: map['repartidor_id'],
      fecha: DateTime.parse(map['fecha'] ?? DateTime.now().toIso8601String()),
      garrafonesSalida: map['garrafones_salida'] ?? 0,
      garrafonesVendidos: map['garrafones_vendidos'] ?? 0,
      garrafonesRegreso: map['garrafones_regreso'] ?? 0,
      garrafonesFaltantes: map['garrafones_faltantes'] ?? 0,
      totalVentas: (map['total_ventas'] ?? 0).toDouble(),
      totalCobranzaAnterior: (map['total_cobranza_anterior'] ?? 0).toDouble(),
      efectivoRecibido: (map['efectivo_recibido'] ?? 0).toDouble(),
      transferenciasRecibidas: (map['transferencias_recibidas'] ?? 0).toDouble(),
      diferencia: (map['diferencia'] ?? 0).toDouble(),
      estado: map['estado'] ?? 'abierto',
      observaciones: map['observaciones'],
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
      rutaNombre: map['purificadora_rutas']?['nombre'],
      repartidorNombre: map['purificadora_repartidores']?['nombre'],
    );
  }

  Map<String, dynamic> toMapForInsert() => {
    'negocio_id': negocioId,
    'ruta_id': rutaId,
    'repartidor_id': repartidorId,
    'fecha': fecha.toIso8601String().split('T')[0],
    'garrafones_salida': garrafonesSalida,
    'garrafones_vendidos': garrafonesVendidos,
    'garrafones_regreso': garrafonesRegreso,
    'garrafones_faltantes': garrafonesFaltantes,
    'total_ventas': totalVentas,
    'total_cobranza_anterior': totalCobranzaAnterior,
    'efectivo_recibido': efectivoRecibido,
    'transferencias_recibidas': transferenciasRecibidas,
    'diferencia': diferencia,
    'estado': estado,
    'observaciones': observaciones,
  };

  bool get cuadra => diferencia == 0;
  double get totalCobrado => efectivoRecibido + transferenciasRecibidas;
}

// Precios por tipo de cliente
class PurificadoraPrecioModel {
  final String id;
  final String? negocioId;
  final String tipoCliente;
  final double precioGarrafon;
  final double precioRecarga;
  final double precioGarrafonNuevo;
  final double depositoGarrafon;
  final bool activo;

  PurificadoraPrecioModel({
    required this.id,
    this.negocioId,
    required this.tipoCliente,
    this.precioGarrafon = 0,
    this.precioRecarga = 0,
    this.precioGarrafonNuevo = 0,
    this.depositoGarrafon = 0,
    this.activo = true,
  });

  factory PurificadoraPrecioModel.fromMap(Map<String, dynamic> map) {
    return PurificadoraPrecioModel(
      id: map['id'] ?? '',
      negocioId: map['negocio_id'],
      tipoCliente: map['tipo_cliente'] ?? '',
      precioGarrafon: (map['precio_garrafon'] ?? 0).toDouble(),
      precioRecarga: (map['precio_recarga'] ?? 0).toDouble(),
      precioGarrafonNuevo: (map['precio_garrafon_nuevo'] ?? 0).toDouble(),
      depositoGarrafon: (map['deposito_garrafon'] ?? 0).toDouble(),
      activo: map['activo'] ?? true,
    );
  }

  Map<String, dynamic> toMapForInsert() => {
    'negocio_id': negocioId,
    'tipo_cliente': tipoCliente,
    'precio_garrafon': precioGarrafon,
    'precio_recarga': precioRecarga,
    'precio_garrafon_nuevo': precioGarrafonNuevo,
    'deposito_garrafon': depositoGarrafon,
    'activo': activo,
  };
}

// Inventario de Garrafones
class PurificadoraInventarioGarrafonesModel {
  final String id;
  final String? negocioId;
  final int garrafonesPlanta;
  final int garrafonesRuta;
  final int garrafonesClientes;
  final int garrafonesDanados;
  final int totalGarrafones;
  final DateTime? ultimaActualizacion;

  PurificadoraInventarioGarrafonesModel({
    required this.id,
    this.negocioId,
    this.garrafonesPlanta = 0,
    this.garrafonesRuta = 0,
    this.garrafonesClientes = 0,
    this.garrafonesDanados = 0,
    this.totalGarrafones = 0,
    this.ultimaActualizacion,
  });

  factory PurificadoraInventarioGarrafonesModel.fromMap(Map<String, dynamic> map) {
    return PurificadoraInventarioGarrafonesModel(
      id: map['id'] ?? '',
      negocioId: map['negocio_id'],
      garrafonesPlanta: map['garrafones_planta'] ?? 0,
      garrafonesRuta: map['garrafones_ruta'] ?? 0,
      garrafonesClientes: map['garrafones_clientes'] ?? 0,
      garrafonesDanados: map['garrafones_danados'] ?? 0,
      totalGarrafones: map['total_garrafones'] ?? 0,
      ultimaActualizacion: map['ultima_actualizacion'] != null 
          ? DateTime.parse(map['ultima_actualizacion']) 
          : null,
    );
  }

  Map<String, dynamic> toMapForInsert() => {
    'negocio_id': negocioId,
    'garrafones_planta': garrafonesPlanta,
    'garrafones_ruta': garrafonesRuta,
    'garrafones_clientes': garrafonesClientes,
    'garrafones_danados': garrafonesDanados,
  };

  int get garrafonesDisponibles => garrafonesPlanta;
  int get garrafonesEnCirculacion => garrafonesRuta + garrafonesClientes;
}
