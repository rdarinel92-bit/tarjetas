/// ═══════════════════════════════════════════════════════════════════════════════
/// MODELOS DEL MÓDULO CLIMAS - Robert Darin Platform
/// ═══════════════════════════════════════════════════════════════════════════════

// Cliente de Climas
class ClimasClienteModel {
  final String id;
  final String? negocioId;
  final String nombre;
  final String? telefono;
  final String? email;
  final String? direccion;
  final String? colonia;
  final String? ciudad;
  final String? codigoPostal;
  final String? referencia;
  final String tipoCliente;
  final String? rfc;
  final String? notas;
  final double? latitud;
  final double? longitud;
  final bool activo;
  final DateTime? createdAt;

  ClimasClienteModel({
    required this.id,
    this.negocioId,
    required this.nombre,
    this.telefono,
    this.email,
    this.direccion,
    this.colonia,
    this.ciudad,
    this.codigoPostal,
    this.referencia,
    this.tipoCliente = 'residencial',
    this.rfc,
    this.notas,
    this.latitud,
    this.longitud,
    this.activo = true,
    this.createdAt,
  });

  factory ClimasClienteModel.fromMap(Map<String, dynamic> map) {
    return ClimasClienteModel(
      id: map['id'] ?? '',
      negocioId: map['negocio_id'],
      nombre: map['nombre'] ?? '',
      telefono: map['telefono'],
      email: map['email'],
      direccion: map['direccion'],
      colonia: map['colonia'],
      ciudad: map['ciudad'],
      codigoPostal: map['codigo_postal'],
      referencia: map['referencia'],
      tipoCliente: map['tipo_cliente'] ?? 'residencial',
      rfc: map['rfc'],
      notas: map['notas'],
      latitud: map['latitud'] != null ? (map['latitud'] as num).toDouble() : null,
      longitud: map['longitud'] != null ? (map['longitud'] as num).toDouble() : null,
      activo: map['activo'] ?? true,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
    );
  }

  Map<String, dynamic> toMapForInsert() => {
    'negocio_id': negocioId,
    'nombre': nombre,
    'telefono': telefono,
    'email': email,
    'direccion': direccion,
    'colonia': colonia,
    'ciudad': ciudad,
    'codigo_postal': codigoPostal,
    'referencia': referencia,
    'tipo_cliente': tipoCliente,
    'rfc': rfc,
    'notas': notas,
    'latitud': latitud,
    'longitud': longitud,
    'activo': activo,
  };
}

// Producto de Climas (Aires)
class ClimasProductoModel {
  final String id;
  final String? negocioId;
  final String? codigo;
  final String nombre;
  final String? marca;
  final String? modelo;
  final int? capacidadBtu;
  final String? tipo;
  final double precioVenta;
  final double precioInstalacion;
  final double costo;
  final int stock;
  final int stockMinimo;
  final int garantiaMeses;
  final String? descripcion;
  final String? imagenUrl;
  final bool activo;

  ClimasProductoModel({
    required this.id,
    this.negocioId,
    this.codigo,
    required this.nombre,
    this.marca,
    this.modelo,
    this.capacidadBtu,
    this.tipo,
    this.precioVenta = 0,
    this.precioInstalacion = 0,
    this.costo = 0,
    this.stock = 0,
    this.stockMinimo = 1,
    this.garantiaMeses = 12,
    this.descripcion,
    this.imagenUrl,
    this.activo = true,
  });

  factory ClimasProductoModel.fromMap(Map<String, dynamic> map) {
    return ClimasProductoModel(
      id: map['id'] ?? '',
      negocioId: map['negocio_id'],
      codigo: map['codigo'],
      nombre: map['nombre'] ?? '',
      marca: map['marca'],
      modelo: map['modelo'],
      capacidadBtu: map['capacidad_btu'],
      tipo: map['tipo'],
      precioVenta: (map['precio_venta'] ?? 0).toDouble(),
      precioInstalacion: (map['precio_instalacion'] ?? 0).toDouble(),
      costo: (map['costo'] ?? 0).toDouble(),
      stock: map['stock'] ?? 0,
      stockMinimo: map['stock_minimo'] ?? 1,
      garantiaMeses: map['garantia_meses'] ?? 12,
      descripcion: map['descripcion'],
      imagenUrl: map['imagen_url'],
      activo: map['activo'] ?? true,
    );
  }

  Map<String, dynamic> toMapForInsert() => {
    'negocio_id': negocioId,
    'codigo': codigo,
    'nombre': nombre,
    'marca': marca,
    'modelo': modelo,
    'capacidad_btu': capacidadBtu,
    'tipo': tipo,
    'precio_venta': precioVenta,
    'precio_instalacion': precioInstalacion,
    'costo': costo,
    'stock': stock,
    'stock_minimo': stockMinimo,
    'garantia_meses': garantiaMeses,
    'descripcion': descripcion,
    'imagen_url': imagenUrl,
    'activo': activo,
  };
  
  String get tipoDisplay {
    switch (tipo) {
      case 'minisplit': return 'Mini Split';
      case 'ventana': return 'Ventana';
      case 'central': return 'Central';
      case 'portatil': return 'Portátil';
      default: return tipo ?? 'General';
    }
  }
}

// Técnico de Climas
class ClimasTecnicoModel {
  final String id;
  final String? negocioId;
  final String? usuarioId;
  final String nombre;
  final String? telefono;
  final String? email;
  final String? especialidad;
  final String nivel;
  final double salarioBase;
  final double comisionPorcentaje;
  final bool activo;

  ClimasTecnicoModel({
    required this.id,
    this.negocioId,
    this.usuarioId,
    required this.nombre,
    this.telefono,
    this.email,
    this.especialidad,
    this.nivel = 'tecnico',
    this.salarioBase = 0,
    this.comisionPorcentaje = 0,
    this.activo = true,
  });

  factory ClimasTecnicoModel.fromMap(Map<String, dynamic> map) {
    return ClimasTecnicoModel(
      id: map['id'] ?? '',
      negocioId: map['negocio_id'],
      usuarioId: map['usuario_id'],
      nombre: map['nombre'] ?? '',
      telefono: map['telefono'],
      email: map['email'],
      especialidad: map['especialidad'],
      nivel: map['nivel'] ?? 'tecnico',
      salarioBase: (map['salario_base'] ?? 0).toDouble(),
      comisionPorcentaje: (map['comision_porcentaje'] ?? 0).toDouble(),
      activo: map['activo'] ?? true,
    );
  }

  Map<String, dynamic> toMapForInsert() => {
    'negocio_id': negocioId,
    'usuario_id': usuarioId,
    'nombre': nombre,
    'telefono': telefono,
    'email': email,
    'especialidad': especialidad,
    'nivel': nivel,
    'salario_base': salarioBase,
    'comision_porcentaje': comisionPorcentaje,
    'activo': activo,
  };
}

// Orden de Servicio
class ClimasOrdenServicioModel {
  final String id;
  final String? negocioId;
  final String? numeroOrden;
  final String? clienteId;
  final String? tecnicoId;
  final String tipoServicio;
  final String prioridad;
  final String estado;
  final DateTime? fechaProgramada;
  final String? horaProgramada;
  final DateTime? fechaCompletada;
  final String? direccionServicio;
  final String? descripcionProblema;
  final String? diagnostico;
  final String? trabajoRealizado;
  final double costoManoObra;
  final double costoMateriales;
  final double costoTotal;
  final String? metodoPago;
  final bool pagado;
  final String? firmaCliente;
  final String? fotoAntes;
  final String? fotoDespues;
  final int? calificacion;
  final String? comentarioCliente;
  final DateTime? createdAt;
  
  // Datos relacionados
  final String? clienteNombre;
  final String? tecnicoNombre;

  ClimasOrdenServicioModel({
    required this.id,
    this.negocioId,
    this.numeroOrden,
    this.clienteId,
    this.tecnicoId,
    required this.tipoServicio,
    this.prioridad = 'normal',
    this.estado = 'pendiente',
    this.fechaProgramada,
    this.horaProgramada,
    this.fechaCompletada,
    this.direccionServicio,
    this.descripcionProblema,
    this.diagnostico,
    this.trabajoRealizado,
    this.costoManoObra = 0,
    this.costoMateriales = 0,
    this.costoTotal = 0,
    this.metodoPago,
    this.pagado = false,
    this.firmaCliente,
    this.fotoAntes,
    this.fotoDespues,
    this.calificacion,
    this.comentarioCliente,
    this.createdAt,
    this.clienteNombre,
    this.tecnicoNombre,
  });

  factory ClimasOrdenServicioModel.fromMap(Map<String, dynamic> map) {
    return ClimasOrdenServicioModel(
      id: map['id'] ?? '',
      negocioId: map['negocio_id'],
      numeroOrden: map['numero_orden'],
      clienteId: map['cliente_id'],
      tecnicoId: map['tecnico_id'],
      tipoServicio: map['tipo_servicio'] ?? '',
      prioridad: map['prioridad'] ?? 'normal',
      estado: map['estado'] ?? 'pendiente',
      fechaProgramada: map['fecha_programada'] != null ? DateTime.parse(map['fecha_programada']) : null,
      horaProgramada: map['hora_programada'],
      fechaCompletada: map['fecha_completada'] != null ? DateTime.parse(map['fecha_completada']) : null,
      direccionServicio: map['direccion_servicio'],
      descripcionProblema: map['descripcion_problema'],
      diagnostico: map['diagnostico'],
      trabajoRealizado: map['trabajo_realizado'],
      costoManoObra: (map['costo_mano_obra'] ?? 0).toDouble(),
      costoMateriales: (map['costo_materiales'] ?? 0).toDouble(),
      costoTotal: (map['costo_total'] ?? 0).toDouble(),
      metodoPago: map['metodo_pago'],
      pagado: map['pagado'] ?? false,
      firmaCliente: map['firma_cliente'],
      fotoAntes: map['foto_antes'],
      fotoDespues: map['foto_despues'],
      calificacion: map['calificacion'],
      comentarioCliente: map['comentario_cliente'],
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
      clienteNombre: map['climas_clientes']?['nombre'],
      tecnicoNombre: map['climas_tecnicos']?['nombre'],
    );
  }

  Map<String, dynamic> toMapForInsert() => {
    'negocio_id': negocioId,
    'numero_orden': numeroOrden,
    'cliente_id': clienteId,
    'tecnico_id': tecnicoId,
    'tipo_servicio': tipoServicio,
    'prioridad': prioridad,
    'estado': estado,
    'fecha_programada': fechaProgramada?.toIso8601String().split('T')[0],
    'hora_programada': horaProgramada,
    'direccion_servicio': direccionServicio,
    'descripcion_problema': descripcionProblema,
  };

  String get tipoServicioDisplay {
    switch (tipoServicio) {
      case 'instalacion': return '🔧 Instalación';
      case 'mantenimiento': return '🛠️ Mantenimiento';
      case 'reparacion': return '⚡ Reparación';
      case 'garantia': return '🛡️ Garantía';
      default: return tipoServicio;
    }
  }

  String get estadoDisplay {
    switch (estado) {
      case 'pendiente': return 'Pendiente';
      case 'programada': return 'Programada';
      case 'en_proceso': return 'En Proceso';
      case 'completada': return 'Completada';
      case 'cancelada': return 'Cancelada';
      default: return estado;
    }
  }
}
