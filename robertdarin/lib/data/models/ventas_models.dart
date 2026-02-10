/// ═══════════════════════════════════════════════════════════════════════════════
/// MODELOS DEL MÓDULO VENTAS/CATÁLOGO - Robert Darin Platform
/// ═══════════════════════════════════════════════════════════════════════════════

// Cliente de Ventas
class VentasClienteModel {
  final String id;
  final String? negocioId;
  final String? codigoCliente;
  final String nombre;
  final String? telefono;
  final String? whatsapp;
  final String? email;
  final String? direccion;
  final String? ciudad;
  final String tipo;
  final double limiteCredito;
  final double saldoPendiente;
  final double descuentoDefault;
  final String? notas;
  final bool activo;
  final DateTime? createdAt;

  VentasClienteModel({
    required this.id,
    this.negocioId,
    this.codigoCliente,
    required this.nombre,
    this.telefono,
    this.whatsapp,
    this.email,
    this.direccion,
    this.ciudad,
    this.tipo = 'minorista',
    this.limiteCredito = 0,
    this.saldoPendiente = 0,
    this.descuentoDefault = 0,
    this.notas,
    this.activo = true,
    this.createdAt,
  });

  factory VentasClienteModel.fromMap(Map<String, dynamic> map) {
    return VentasClienteModel(
      id: map['id'] ?? '',
      negocioId: map['negocio_id'],
      codigoCliente: map['codigo_cliente'],
      nombre: map['nombre'] ?? '',
      telefono: map['telefono'],
      whatsapp: map['whatsapp'],
      email: map['email'],
      direccion: map['direccion'],
      ciudad: map['ciudad'],
      tipo: map['tipo'] ?? 'minorista',
      limiteCredito: (map['limite_credito'] ?? 0).toDouble(),
      saldoPendiente: (map['saldo_pendiente'] ?? 0).toDouble(),
      descuentoDefault: (map['descuento_default'] ?? 0).toDouble(),
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
    'email': email,
    'direccion': direccion,
    'ciudad': ciudad,
    'tipo': tipo,
    'limite_credito': limiteCredito,
    'descuento_default': descuentoDefault,
    'notas': notas,
    'activo': activo,
  };
}

// Categoría de Productos
class VentasCategoriaModel {
  final String id;
  final String? negocioId;
  final String nombre;
  final String? descripcion;
  final String? imagenUrl;
  final int orden;
  final bool activo;

  VentasCategoriaModel({
    required this.id,
    this.negocioId,
    required this.nombre,
    this.descripcion,
    this.imagenUrl,
    this.orden = 0,
    this.activo = true,
  });

  factory VentasCategoriaModel.fromMap(Map<String, dynamic> map) {
    return VentasCategoriaModel(
      id: map['id'] ?? '',
      negocioId: map['negocio_id'],
      nombre: map['nombre'] ?? '',
      descripcion: map['descripcion'],
      imagenUrl: map['imagen_url'],
      orden: map['orden'] ?? 0,
      activo: map['activo'] ?? true,
    );
  }

  Map<String, dynamic> toMapForInsert() => {
    'negocio_id': negocioId,
    'nombre': nombre,
    'descripcion': descripcion,
    'imagen_url': imagenUrl,
    'orden': orden,
    'activo': activo,
  };
}

// Producto
class VentasProductoModel {
  final String id;
  final String? negocioId;
  final String? categoriaId;
  final String? codigoBarras;
  final String? sku;
  final String nombre;
  final String? descripcion;
  final String? marca;
  final String? modelo;
  final String unidadMedida;
  final double precioCosto;
  final double precioVenta;
  final double precioMayoreo;
  final int cantidadMayoreo;
  final int stockActual;
  final int stockMinimo;
  final int stockMaximo;
  final String? imagenUrl;
  final List<String> galeria;
  final Map<String, dynamic> especificaciones;
  final bool activo;
  final bool destacado;
  final DateTime? createdAt;
  
  // Relación
  final String? categoriaNombre;

  VentasProductoModel({
    required this.id,
    this.negocioId,
    this.categoriaId,
    this.codigoBarras,
    this.sku,
    required this.nombre,
    this.descripcion,
    this.marca,
    this.modelo,
    this.unidadMedida = 'pza',
    this.precioCosto = 0,
    this.precioVenta = 0,
    this.precioMayoreo = 0,
    this.cantidadMayoreo = 10,
    this.stockActual = 0,
    this.stockMinimo = 1,
    this.stockMaximo = 100,
    this.imagenUrl,
    this.galeria = const [],
    this.especificaciones = const {},
    this.activo = true,
    this.destacado = false,
    this.createdAt,
    this.categoriaNombre,
  });

  factory VentasProductoModel.fromMap(Map<String, dynamic> map) {
    return VentasProductoModel(
      id: map['id'] ?? '',
      negocioId: map['negocio_id'],
      categoriaId: map['categoria_id'],
      codigoBarras: map['codigo_barras'],
      sku: map['sku'],
      nombre: map['nombre'] ?? '',
      descripcion: map['descripcion'],
      marca: map['marca'],
      modelo: map['modelo'],
      unidadMedida: map['unidad_medida'] ?? 'pza',
      precioCosto: (map['precio_costo'] ?? 0).toDouble(),
      precioVenta: (map['precio_venta'] ?? 0).toDouble(),
      precioMayoreo: (map['precio_mayoreo'] ?? 0).toDouble(),
      cantidadMayoreo: map['cantidad_mayoreo'] ?? 10,
      stockActual: map['stock_actual'] ?? 0,
      stockMinimo: map['stock_minimo'] ?? 1,
      stockMaximo: map['stock_maximo'] ?? 100,
      imagenUrl: map['imagen_url'],
      galeria: map['galeria'] != null ? List<String>.from(map['galeria']) : [],
      especificaciones: map['especificaciones'] ?? {},
      activo: map['activo'] ?? true,
      destacado: map['destacado'] ?? false,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
      categoriaNombre: map['ventas_categorias']?['nombre'],
    );
  }

  Map<String, dynamic> toMapForInsert() => {
    'negocio_id': negocioId,
    'categoria_id': categoriaId,
    'codigo_barras': codigoBarras,
    'sku': sku,
    'nombre': nombre,
    'descripcion': descripcion,
    'marca': marca,
    'modelo': modelo,
    'unidad_medida': unidadMedida,
    'precio_costo': precioCosto,
    'precio_venta': precioVenta,
    'precio_mayoreo': precioMayoreo,
    'cantidad_mayoreo': cantidadMayoreo,
    'stock_actual': stockActual,
    'stock_minimo': stockMinimo,
    'stock_maximo': stockMaximo,
    'imagen_url': imagenUrl,
    'galeria': galeria,
    'especificaciones': especificaciones,
    'activo': activo,
    'destacado': destacado,
  };

  double get utilidad => precioVenta - precioCosto;
  double get margenPorcentaje => precioCosto > 0 ? ((precioVenta - precioCosto) / precioCosto) * 100 : 0;
  bool get stockBajo => stockActual <= stockMinimo;
}

// Vendedor
class VentasVendedorModel {
  final String id;
  final String? negocioId;
  final String? usuarioId;
  final String nombre;
  final String? telefono;
  final String? email;
  final double metaMensual;
  final double comisionPorcentaje;
  final double ventasMes;
  final bool activo;

  VentasVendedorModel({
    required this.id,
    this.negocioId,
    this.usuarioId,
    required this.nombre,
    this.telefono,
    this.email,
    this.metaMensual = 0,
    this.comisionPorcentaje = 0,
    this.ventasMes = 0,
    this.activo = true,
  });

  factory VentasVendedorModel.fromMap(Map<String, dynamic> map) {
    return VentasVendedorModel(
      id: map['id'] ?? '',
      negocioId: map['negocio_id'],
      usuarioId: map['usuario_id'],
      nombre: map['nombre'] ?? '',
      telefono: map['telefono'],
      email: map['email'],
      metaMensual: (map['meta_mensual'] ?? 0).toDouble(),
      comisionPorcentaje: (map['comision_porcentaje'] ?? 0).toDouble(),
      ventasMes: (map['ventas_mes'] ?? 0).toDouble(),
      activo: map['activo'] ?? true,
    );
  }

  Map<String, dynamic> toMapForInsert() => {
    'negocio_id': negocioId,
    'usuario_id': usuarioId,
    'nombre': nombre,
    'telefono': telefono,
    'email': email,
    'meta_mensual': metaMensual,
    'comision_porcentaje': comisionPorcentaje,
    'activo': activo,
  };

  double get cumplimientoMeta => metaMensual > 0 ? (ventasMes / metaMensual) * 100 : 0;
}

// Pedido
class VentasPedidoModel {
  final String id;
  final String? negocioId;
  final String? numeroPedido;
  final String? clienteId;
  final String? vendedorId;
  final String estado;
  final String tipoVenta;
  final DateTime? fechaPedido;
  final DateTime? fechaEntregaEstimada;
  final DateTime? fechaEntregado;
  final double subtotal;
  final double descuento;
  final double iva;
  final double total;
  final String? metodoPago;
  final bool pagado;
  final double montoPagado;
  final double saldoPendiente;
  final String? direccionEntrega;
  final String? notas;
  final DateTime? createdAt;
  
  // Relaciones
  final String? clienteNombre;
  final String? vendedorNombre;
  final List<VentasPedidoDetalleModel> detalle;

  VentasPedidoModel({
    required this.id,
    this.negocioId,
    this.numeroPedido,
    this.clienteId,
    this.vendedorId,
    this.estado = 'pendiente',
    this.tipoVenta = 'mostrador',
    this.fechaPedido,
    this.fechaEntregaEstimada,
    this.fechaEntregado,
    this.subtotal = 0,
    this.descuento = 0,
    this.iva = 0,
    this.total = 0,
    this.metodoPago,
    this.pagado = false,
    this.montoPagado = 0,
    this.saldoPendiente = 0,
    this.direccionEntrega,
    this.notas,
    this.createdAt,
    this.clienteNombre,
    this.vendedorNombre,
    this.detalle = const [],
  });

  factory VentasPedidoModel.fromMap(Map<String, dynamic> map) {
    return VentasPedidoModel(
      id: map['id'] ?? '',
      negocioId: map['negocio_id'],
      numeroPedido: map['numero_pedido'],
      clienteId: map['cliente_id'],
      vendedorId: map['vendedor_id'],
      estado: map['estado'] ?? 'pendiente',
      tipoVenta: map['tipo_venta'] ?? 'mostrador',
      fechaPedido: map['fecha_pedido'] != null ? DateTime.parse(map['fecha_pedido']) : null,
      fechaEntregaEstimada: map['fecha_entrega_estimada'] != null ? DateTime.parse(map['fecha_entrega_estimada']) : null,
      fechaEntregado: map['fecha_entregado'] != null ? DateTime.parse(map['fecha_entregado']) : null,
      subtotal: (map['subtotal'] ?? 0).toDouble(),
      descuento: (map['descuento'] ?? 0).toDouble(),
      iva: (map['iva'] ?? 0).toDouble(),
      total: (map['total'] ?? 0).toDouble(),
      metodoPago: map['metodo_pago'],
      pagado: map['pagado'] ?? false,
      montoPagado: (map['monto_pagado'] ?? 0).toDouble(),
      saldoPendiente: (map['saldo_pendiente'] ?? 0).toDouble(),
      direccionEntrega: map['direccion_entrega'],
      notas: map['notas'],
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
      clienteNombre: map['ventas_clientes']?['nombre'],
      vendedorNombre: map['ventas_vendedores']?['nombre'],
    );
  }

  Map<String, dynamic> toMapForInsert() => {
    'negocio_id': negocioId,
    'numero_pedido': numeroPedido,
    'cliente_id': clienteId,
    'vendedor_id': vendedorId,
    'estado': estado,
    'tipo_venta': tipoVenta,
    'fecha_entrega_estimada': fechaEntregaEstimada?.toIso8601String().split('T')[0],
    'subtotal': subtotal,
    'descuento': descuento,
    'iva': iva,
    'total': total,
    'metodo_pago': metodoPago,
    'direccion_entrega': direccionEntrega,
    'notas': notas,
  };

  String get estadoDisplay {
    switch (estado) {
      case 'pendiente': return '⏳ Pendiente';
      case 'confirmado': return '✅ Confirmado';
      case 'preparando': return '📦 Preparando';
      case 'enviado': return '🚚 Enviado';
      case 'entregado': return '✔️ Entregado';
      case 'cancelado': return '❌ Cancelado';
      default: return estado;
    }
  }
}

// Detalle de Pedido
class VentasPedidoDetalleModel {
  final String id;
  final String? pedidoId;
  final String? productoId;
  final int cantidad;
  final double precioUnitario;
  final double descuento;
  final double subtotal;
  final String? notas;
  
  // Relación
  final String? productoNombre;

  VentasPedidoDetalleModel({
    required this.id,
    this.pedidoId,
    this.productoId,
    this.cantidad = 1,
    this.precioUnitario = 0,
    this.descuento = 0,
    this.subtotal = 0,
    this.notas,
    this.productoNombre,
  });

  factory VentasPedidoDetalleModel.fromMap(Map<String, dynamic> map) {
    return VentasPedidoDetalleModel(
      id: map['id'] ?? '',
      pedidoId: map['pedido_id'],
      productoId: map['producto_id'],
      cantidad: map['cantidad'] ?? 1,
      precioUnitario: (map['precio_unitario'] ?? 0).toDouble(),
      descuento: (map['descuento'] ?? 0).toDouble(),
      subtotal: (map['subtotal'] ?? 0).toDouble(),
      notas: map['notas'],
      productoNombre: map['ventas_productos']?['nombre'],
    );
  }

  Map<String, dynamic> toMapForInsert() => {
    'pedido_id': pedidoId,
    'producto_id': productoId,
    'cantidad': cantidad,
    'precio_unitario': precioUnitario,
    'descuento': descuento,
    'subtotal': subtotal,
    'notas': notas,
  };
}

// Apartado
class VentasApartadoModel {
  final String id;
  final String? negocioId;
  final String? numeroApartado;
  final String? clienteId;
  final String? productoId;
  final int cantidad;
  final double precioTotal;
  final double enganche;
  final double saldoPendiente;
  final DateTime? fechaLimite;
  final String estado;
  final DateTime? createdAt;
  
  // Relaciones
  final String? clienteNombre;
  final String? productoNombre;

  VentasApartadoModel({
    required this.id,
    this.negocioId,
    this.numeroApartado,
    this.clienteId,
    this.productoId,
    this.cantidad = 1,
    this.precioTotal = 0,
    this.enganche = 0,
    this.saldoPendiente = 0,
    this.fechaLimite,
    this.estado = 'activo',
    this.createdAt,
    this.clienteNombre,
    this.productoNombre,
  });

  factory VentasApartadoModel.fromMap(Map<String, dynamic> map) {
    return VentasApartadoModel(
      id: map['id'] ?? '',
      negocioId: map['negocio_id'],
      numeroApartado: map['numero_apartado'],
      clienteId: map['cliente_id'],
      productoId: map['producto_id'],
      cantidad: map['cantidad'] ?? 1,
      precioTotal: (map['precio_total'] ?? 0).toDouble(),
      enganche: (map['enganche'] ?? 0).toDouble(),
      saldoPendiente: (map['saldo_pendiente'] ?? 0).toDouble(),
      fechaLimite: map['fecha_limite'] != null ? DateTime.parse(map['fecha_limite']) : null,
      estado: map['estado'] ?? 'activo',
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
      clienteNombre: map['ventas_clientes']?['nombre'],
      productoNombre: map['ventas_productos']?['nombre'],
    );
  }

  Map<String, dynamic> toMapForInsert() => {
    'negocio_id': negocioId,
    'numero_apartado': numeroApartado,
    'cliente_id': clienteId,
    'producto_id': productoId,
    'cantidad': cantidad,
    'precio_total': precioTotal,
    'enganche': enganche,
    'saldo_pendiente': saldoPendiente,
    'fecha_limite': fechaLimite?.toIso8601String().split('T')[0],
    'estado': estado,
  };

  double get porcentajePagado => precioTotal > 0 ? ((precioTotal - saldoPendiente) / precioTotal) * 100 : 0;
}
