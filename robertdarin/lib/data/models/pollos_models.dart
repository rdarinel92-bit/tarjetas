/// ═══════════════════════════════════════════════════════════════════════════════
/// MODELOS PARA MÓDULO POLLOS ASADOS
/// Sistema de pedidos de pollos asados
/// ═══════════════════════════════════════════════════════════════════════════════

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MODELO: Configuración del negocio
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class PollosConfigModel {
  final String id;
  final String? negocioId;
  final String nombreNegocio;
  final String? slogan;
  final String? telefono;
  final String? whatsapp;
  final String? direccion;
  final String? horarioApertura;
  final String? horarioCierre;
  final int tiempoPreparacionMin;
  final double pedidoMinimo;
  final bool aceptaPedidosWeb;
  final bool tieneDelivery;
  final double costoDelivery;
  final double radioDeliveryKm;
  final double deliveryGratisDesde;
  final String? logoUrl;
  final String colorPrimario;
  final String colorSecundario;
  final bool activo;

  PollosConfigModel({
    required this.id,
    this.negocioId,
    this.nombreNegocio = 'Pollos Asados',
    this.slogan,
    this.telefono,
    this.whatsapp,
    this.direccion,
    this.horarioApertura,
    this.horarioCierre,
    this.tiempoPreparacionMin = 20,
    this.pedidoMinimo = 0,
    this.aceptaPedidosWeb = true,
    this.tieneDelivery = true,
    this.costoDelivery = 30.0,
    this.radioDeliveryKm = 5.0,
    this.deliveryGratisDesde = 300.0,
    this.logoUrl,
    this.colorPrimario = '#FF6B00',
    this.colorSecundario = '#FFD93D',
    this.activo = true,
  });

  factory PollosConfigModel.fromMap(Map<String, dynamic> map) {
    return PollosConfigModel(
      id: map['id'] ?? '',
      negocioId: map['negocio_id'],
      nombreNegocio: map['nombre_negocio'] ?? 'Pollos Asados',
      slogan: map['slogan'],
      telefono: map['telefono'],
      whatsapp: map['whatsapp'],
      direccion: map['direccion'],
      horarioApertura: map['horario_apertura'],
      horarioCierre: map['horario_cierre'],
      tiempoPreparacionMin: map['tiempo_preparacion_min'] ?? 20,
      pedidoMinimo: (map['pedido_minimo'] ?? 0).toDouble(),
      aceptaPedidosWeb: map['acepta_pedidos_web'] ?? true,
      tieneDelivery: map['tiene_delivery'] ?? true,
      costoDelivery: (map['costo_delivery'] ?? 30).toDouble(),
      radioDeliveryKm: (map['radio_delivery_km'] ?? 5).toDouble(),
      deliveryGratisDesde: (map['delivery_gratis_desde'] ?? 300).toDouble(),
      logoUrl: map['logo_url'],
      colorPrimario: map['color_primario'] ?? '#FF6B00',
      colorSecundario: map['color_secundario'] ?? '#FFD93D',
      activo: map['activo'] ?? true,
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MODELO: Producto del menú
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class PollosProductoModel {
  final String id;
  final String? negocioId;
  final String nombre;
  final String? descripcion;
  final String categoria;
  final double precio;
  final double? precioPromocion;
  final bool enPromocion;
  final bool disponible;
  final String? imagenUrl;
  final int orden;
  final bool destacado;
  final bool activo;

  PollosProductoModel({
    required this.id,
    this.negocioId,
    required this.nombre,
    this.descripcion,
    this.categoria = 'pollos',
    required this.precio,
    this.precioPromocion,
    this.enPromocion = false,
    this.disponible = true,
    this.imagenUrl,
    this.orden = 0,
    this.destacado = false,
    this.activo = true,
  });

  factory PollosProductoModel.fromMap(Map<String, dynamic> map) {
    return PollosProductoModel(
      id: map['id'] ?? '',
      negocioId: map['negocio_id'],
      nombre: map['nombre'] ?? '',
      descripcion: map['descripcion'],
      categoria: map['categoria'] ?? 'pollos',
      precio: (map['precio'] ?? 0).toDouble(),
      precioPromocion: map['precio_promocion'] != null ? (map['precio_promocion']).toDouble() : null,
      enPromocion: map['en_promocion'] ?? false,
      disponible: map['disponible'] ?? true,
      imagenUrl: map['imagen_url'],
      orden: map['orden'] ?? 0,
      destacado: map['destacado'] ?? false,
      activo: map['activo'] ?? true,
    );
  }

  double get precioFinal => enPromocion && precioPromocion != null ? precioPromocion! : precio;
  
  String get categoriaDisplay {
    switch (categoria) {
      case 'pollos': return '🍗 Pollos';
      case 'complementos': return '🍟 Complementos';
      case 'bebidas': return '🥤 Bebidas';
      case 'combos': return '🎁 Combos';
      default: return categoria;
    }
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MODELO: Pedido
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class PollosPedidoModel {
  final String id;
  final String? negocioId;
  final int? numeroPedido;
  final String clienteNombre;
  final String clienteTelefono;
  final String? clienteEmail;
  final String tipoEntrega;
  final String? direccionEntrega;
  final String? referenciaDireccion;
  final double subtotal;
  final double costoDelivery;
  final double descuento;
  final double total;
  final String estado;
  final String metodoPago;
  final bool pagado;
  final DateTime? horaPedido;
  final DateTime? horaConfirmacion;
  final DateTime? horaListo;
  final DateTime? horaEntrega;
  final int? tiempoEstimadoMin;
  final String? notasCliente;
  final String? notasInternas;
  final String origen;
  final String? tokenSeguimiento;
  final List<PollosPedidoDetalleModel> items;

  PollosPedidoModel({
    required this.id,
    this.negocioId,
    this.numeroPedido,
    required this.clienteNombre,
    required this.clienteTelefono,
    this.clienteEmail,
    this.tipoEntrega = 'recoger',
    this.direccionEntrega,
    this.referenciaDireccion,
    this.subtotal = 0,
    this.costoDelivery = 0,
    this.descuento = 0,
    this.total = 0,
    this.estado = 'pendiente',
    this.metodoPago = 'efectivo',
    this.pagado = false,
    this.horaPedido,
    this.horaConfirmacion,
    this.horaListo,
    this.horaEntrega,
    this.tiempoEstimadoMin,
    this.notasCliente,
    this.notasInternas,
    this.origen = 'web',
    this.tokenSeguimiento,
    this.items = const [],
  });

  factory PollosPedidoModel.fromMap(Map<String, dynamic> map) {
    return PollosPedidoModel(
      id: map['id'] ?? '',
      negocioId: map['negocio_id'],
      numeroPedido: map['numero_pedido'],
      clienteNombre: map['cliente_nombre'] ?? '',
      clienteTelefono: map['cliente_telefono'] ?? '',
      clienteEmail: map['cliente_email'],
      tipoEntrega: map['tipo_entrega'] ?? 'recoger',
      direccionEntrega: map['direccion_entrega'],
      referenciaDireccion: map['referencia_direccion'],
      subtotal: (map['subtotal'] ?? 0).toDouble(),
      costoDelivery: (map['costo_delivery'] ?? 0).toDouble(),
      descuento: (map['descuento'] ?? 0).toDouble(),
      total: (map['total'] ?? 0).toDouble(),
      estado: map['estado'] ?? 'pendiente',
      metodoPago: map['metodo_pago'] ?? 'efectivo',
      pagado: map['pagado'] ?? false,
      horaPedido: map['hora_pedido'] != null ? DateTime.parse(map['hora_pedido']) : null,
      horaConfirmacion: map['hora_confirmacion'] != null ? DateTime.parse(map['hora_confirmacion']) : null,
      horaListo: map['hora_listo'] != null ? DateTime.parse(map['hora_listo']) : null,
      horaEntrega: map['hora_entrega'] != null ? DateTime.parse(map['hora_entrega']) : null,
      tiempoEstimadoMin: map['tiempo_estimado_min'],
      notasCliente: map['notas_cliente'],
      notasInternas: map['notas_internas'],
      origen: map['origen'] ?? 'web',
      tokenSeguimiento: map['token_seguimiento'],
      items: map['pollos_pedido_detalle'] != null
          ? (map['pollos_pedido_detalle'] as List).map((e) => PollosPedidoDetalleModel.fromMap(e)).toList()
          : [],
    );
  }

  Map<String, dynamic> toMapForInsert() => {
    'negocio_id': negocioId,
    'cliente_nombre': clienteNombre,
    'cliente_telefono': clienteTelefono,
    'cliente_email': clienteEmail,
    'tipo_entrega': tipoEntrega,
    'direccion_entrega': direccionEntrega,
    'referencia_direccion': referenciaDireccion,
    'costo_delivery': costoDelivery,
    'metodo_pago': metodoPago,
    'notas_cliente': notasCliente,
    'origen': origen,
  };

  String get estadoDisplay {
    switch (estado) {
      case 'pendiente': return '⏳ Pendiente';
      case 'confirmado': return '✅ Confirmado';
      case 'preparando': return '🍳 Preparando';
      case 'listo': return '🔔 Listo';
      case 'en_camino': return '🚗 En camino';
      case 'entregado': return '✔️ Entregado';
      case 'cancelado': return '❌ Cancelado';
      default: return estado;
    }
  }

  String get tipoEntregaDisplay => tipoEntrega == 'delivery' ? '🚗 Delivery' : '🏪 Recoger';
  bool get esDelivery => tipoEntrega == 'delivery';
  bool get estaActivo => !['entregado', 'cancelado'].contains(estado);
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MODELO: Detalle del pedido (productos)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class PollosPedidoDetalleModel {
  final String id;
  final String pedidoId;
  final String? productoId;
  final String productoNombre;
  final int cantidad;
  final double precioUnitario;
  final double subtotal;
  final String? notas;

  PollosPedidoDetalleModel({
    required this.id,
    required this.pedidoId,
    this.productoId,
    required this.productoNombre,
    this.cantidad = 1,
    required this.precioUnitario,
    required this.subtotal,
    this.notas,
  });

  factory PollosPedidoDetalleModel.fromMap(Map<String, dynamic> map) {
    return PollosPedidoDetalleModel(
      id: map['id'] ?? '',
      pedidoId: map['pedido_id'] ?? '',
      productoId: map['producto_id'],
      productoNombre: map['producto_nombre'] ?? '',
      cantidad: map['cantidad'] ?? 1,
      precioUnitario: (map['precio_unitario'] ?? 0).toDouble(),
      subtotal: (map['subtotal'] ?? 0).toDouble(),
      notas: map['notas'],
    );
  }

  Map<String, dynamic> toMapForInsert() => {
    'pedido_id': pedidoId,
    'producto_id': productoId,
    'producto_nombre': productoNombre,
    'cantidad': cantidad,
    'precio_unitario': precioUnitario,
    'subtotal': subtotal,
    'notas': notas,
  };
}
