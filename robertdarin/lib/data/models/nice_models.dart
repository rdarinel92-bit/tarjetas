// ═══════════════════════════════════════════════════════════════════════════════
// MODELOS PARA MÓDULO NICE (JOYERÍA Y ACCESORIOS)
// Robert Darin Platform v10.20
// ═══════════════════════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════════════════════
// CATÁLOGO
// ═══════════════════════════════════════════════════════════════════════════════

class NiceCatalogo {
  final String id;
  final String? negocioId;
  final String codigo;
  final String nombre;
  final String? descripcion;
  final String? imagenPortadaUrl;
  final String? pdfUrl;
  final DateTime? fechaInicio;
  final DateTime? fechaFin;
  final bool activo;
  final int orden;
  final DateTime? createdAt;

  NiceCatalogo({
    required this.id,
    this.negocioId,
    required this.codigo,
    required this.nombre,
    this.descripcion,
    this.imagenPortadaUrl,
    this.pdfUrl,
    this.fechaInicio,
    this.fechaFin,
    this.activo = true,
    this.orden = 0,
    this.createdAt,
  });

  factory NiceCatalogo.fromMap(Map<String, dynamic> map) {
    return NiceCatalogo(
      id: map['id'] ?? '',
      negocioId: map['negocio_id'],
      codigo: map['codigo'] ?? '',
      nombre: map['nombre'] ?? '',
      descripcion: map['descripcion'],
      imagenPortadaUrl: map['imagen_portada_url'],
      pdfUrl: map['pdf_url'],
      fechaInicio: map['fecha_inicio'] != null ? DateTime.parse(map['fecha_inicio']) : null,
      fechaFin: map['fecha_fin'] != null ? DateTime.parse(map['fecha_fin']) : null,
      activo: map['activo'] ?? true,
      orden: map['orden'] ?? 0,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'negocio_id': negocioId,
    'codigo': codigo,
    'nombre': nombre,
    'descripcion': descripcion,
    'imagen_portada_url': imagenPortadaUrl,
    'pdf_url': pdfUrl,
    'fecha_inicio': fechaInicio?.toIso8601String().split('T')[0],
    'fecha_fin': fechaFin?.toIso8601String().split('T')[0],
    'activo': activo,
    'orden': orden,
  };

  Map<String, dynamic> toMapForInsert() {
    final map = toMap();
    map.remove('id');
    return map;
  }

  bool get estaVigente {
    final now = DateTime.now();
    if (fechaInicio != null && now.isBefore(fechaInicio!)) return false;
    if (fechaFin != null && now.isAfter(fechaFin!)) return false;
    return activo;
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CATEGORÍA
// ═══════════════════════════════════════════════════════════════════════════════

class NiceCategoria {
  final String id;
  final String? negocioId;
  final String nombre;
  final String? descripcion;
  final String icono;
  final String color;
  final String? imagenUrl;
  final int orden;
  final bool activo;

  NiceCategoria({
    required this.id,
    this.negocioId,
    required this.nombre,
    this.descripcion,
    this.icono = 'diamond',
    this.color = '#FFD700',
    this.imagenUrl,
    this.orden = 0,
    this.activo = true,
  });

  factory NiceCategoria.fromMap(Map<String, dynamic> map) {
    return NiceCategoria(
      id: map['id'] ?? '',
      negocioId: map['negocio_id'],
      nombre: map['nombre'] ?? '',
      descripcion: map['descripcion'],
      icono: map['icono'] ?? 'diamond',
      color: map['color'] ?? '#FFD700',
      imagenUrl: map['imagen_url'],
      orden: map['orden'] ?? 0,
      activo: map['activo'] ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'negocio_id': negocioId,
    'nombre': nombre,
    'descripcion': descripcion,
    'icono': icono,
    'color': color,
    'imagen_url': imagenUrl,
    'orden': orden,
    'activo': activo,
  };
}

// ═══════════════════════════════════════════════════════════════════════════════
// PRODUCTO
// ═══════════════════════════════════════════════════════════════════════════════

class NiceProducto {
  final String id;
  final String? negocioId;
  final String? categoriaId;
  final String? catalogoId;
  final String sku;
  final String nombre;
  final String? descripcion;
  final double precioCatalogo;
  final double precioVendedora;
  final double costo;
  final int stock;
  final int stockMinimo;
  final String? imagenPrincipalUrl;
  final List<String> imagenesAdicionales;
  final String? material;
  final String? color;
  final String? talla;
  final double? pesoGramos;
  final int? paginaCatalogo;
  final bool esNuevo;
  final bool esDestacado;
  final bool esOferta;
  final double? precioOferta;
  final bool activo;
  final bool disponible;
  final int vecesVendido;
  
  // Datos de relaciones
  final String? categoriaNombre;
  final String? categoriaIcono;
  final String? categoriaColor;
  final String? catalogoCodigo;
  final String? catalogoNombre;

  NiceProducto({
    required this.id,
    this.negocioId,
    this.categoriaId,
    this.catalogoId,
    required this.sku,
    required this.nombre,
    this.descripcion,
    required this.precioCatalogo,
    required this.precioVendedora,
    this.costo = 0,
    this.stock = 0,
    this.stockMinimo = 5,
    this.imagenPrincipalUrl,
    this.imagenesAdicionales = const [],
    this.material,
    this.color,
    this.talla,
    this.pesoGramos,
    this.paginaCatalogo,
    this.esNuevo = false,
    this.esDestacado = false,
    this.esOferta = false,
    this.precioOferta,
    this.activo = true,
    this.disponible = true,
    this.vecesVendido = 0,
    this.categoriaNombre,
    this.categoriaIcono,
    this.categoriaColor,
    this.catalogoCodigo,
    this.catalogoNombre,
  });

  factory NiceProducto.fromMap(Map<String, dynamic> map) {
    List<String> imagenes = [];
    if (map['imagenes_adicionales'] != null) {
      if (map['imagenes_adicionales'] is List) {
        imagenes = List<String>.from(map['imagenes_adicionales']);
      }
    }

    return NiceProducto(
      id: map['id'] ?? '',
      negocioId: map['negocio_id'],
      categoriaId: map['categoria_id'],
      catalogoId: map['catalogo_id'],
      sku: map['sku'] ?? '',
      nombre: map['nombre'] ?? '',
      descripcion: map['descripcion'],
      precioCatalogo: (map['precio_catalogo'] ?? 0).toDouble(),
      precioVendedora: (map['precio_vendedora'] ?? 0).toDouble(),
      costo: (map['costo'] ?? 0).toDouble(),
      stock: map['stock'] ?? 0,
      stockMinimo: map['stock_minimo'] ?? 5,
      imagenPrincipalUrl: map['imagen_principal_url'],
      imagenesAdicionales: imagenes,
      material: map['material'],
      color: map['color'],
      talla: map['talla'],
      pesoGramos: map['peso_gramos']?.toDouble(),
      paginaCatalogo: map['pagina_catalogo'],
      esNuevo: map['es_nuevo'] ?? false,
      esDestacado: map['es_destacado'] ?? false,
      esOferta: map['es_oferta'] ?? false,
      precioOferta: map['precio_oferta']?.toDouble(),
      activo: map['activo'] ?? true,
      disponible: map['disponible'] ?? true,
      vecesVendido: map['veces_vendido'] ?? 0,
      categoriaNombre: map['categoria_nombre'],
      categoriaIcono: map['categoria_icono'],
      categoriaColor: map['categoria_color'],
      catalogoCodigo: map['catalogo_codigo'],
      catalogoNombre: map['catalogo_nombre'],
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'negocio_id': negocioId,
    'categoria_id': categoriaId,
    'catalogo_id': catalogoId,
    'sku': sku,
    'nombre': nombre,
    'descripcion': descripcion,
    'precio_catalogo': precioCatalogo,
    'precio_vendedora': precioVendedora,
    'costo': costo,
    'stock': stock,
    'stock_minimo': stockMinimo,
    'imagen_principal_url': imagenPrincipalUrl,
    'imagenes_adicionales': imagenesAdicionales,
    'material': material,
    'color': color,
    'talla': talla,
    'peso_gramos': pesoGramos,
    'pagina_catalogo': paginaCatalogo,
    'es_nuevo': esNuevo,
    'es_destacado': esDestacado,
    'es_oferta': esOferta,
    'precio_oferta': precioOferta,
    'activo': activo,
    'disponible': disponible,
  };

  Map<String, dynamic> toMapForInsert() {
    final map = toMap();
    map.remove('id');
    return map;
  }

  double get gananciaUnitaria => precioCatalogo - precioVendedora;
  double get porcentajeGanancia => precioCatalogo > 0 ? (gananciaUnitaria / precioCatalogo * 100) : 0;
  double get precioFinal => esOferta && precioOferta != null ? precioOferta! : precioCatalogo;
  String get stockStatus => stock <= 0 ? 'agotado' : (stock <= stockMinimo ? 'bajo' : 'disponible');
  
  // Aliases de compatibilidad
  int get stockActual => stock;
  double get precioBase => precioVendedora;
  double get precioPublico => precioCatalogo;
  String get codigoProducto => sku;
  String? get imagenUrl => imagenPrincipalUrl;
}

// ═══════════════════════════════════════════════════════════════════════════════
// NIVEL DE VENDEDORA
// ═══════════════════════════════════════════════════════════════════════════════

class NiceNivel {
  final String id;
  final String? negocioId;
  final String codigo;
  final String nombre;
  final String? descripcion;
  final double ventasMinimasMes;
  final int equipoMinimo;
  final int puntosMinimos;
  final double descuentoPorcentaje;
  final double comisionVentas;
  final double comisionEquipoN1;
  final double comisionEquipoN2;
  final double comisionEquipoN3;
  final double bonoRango;
  final double bonoLiderazgo;
  final String color;
  final String icono;
  final String? insigniaUrl;
  final int orden;
  final bool activo;

  NiceNivel({
    required this.id,
    this.negocioId,
    required this.codigo,
    required this.nombre,
    this.descripcion,
    this.ventasMinimasMes = 0,
    this.equipoMinimo = 0,
    this.puntosMinimos = 0,
    this.descuentoPorcentaje = 0,
    this.comisionVentas = 0,
    this.comisionEquipoN1 = 0,
    this.comisionEquipoN2 = 0,
    this.comisionEquipoN3 = 0,
    this.bonoRango = 0,
    this.bonoLiderazgo = 0,
    this.color = '#666666',
    this.icono = 'star',
    this.insigniaUrl,
    this.orden = 0,
    this.activo = true,
  });

  factory NiceNivel.fromMap(Map<String, dynamic> map) {
    return NiceNivel(
      id: map['id'] ?? '',
      negocioId: map['negocio_id'],
      codigo: map['codigo'] ?? '',
      nombre: map['nombre'] ?? '',
      descripcion: map['descripcion'],
      ventasMinimasMes: (map['ventas_minimas_mes'] ?? 0).toDouble(),
      equipoMinimo: map['equipo_minimo'] ?? 0,
      puntosMinimos: map['puntos_minimos'] ?? 0,
      descuentoPorcentaje: (map['descuento_porcentaje'] ?? 0).toDouble(),
      comisionVentas: (map['comision_ventas'] ?? 0).toDouble(),
      comisionEquipoN1: (map['comision_equipo_n1'] ?? 0).toDouble(),
      comisionEquipoN2: (map['comision_equipo_n2'] ?? 0).toDouble(),
      comisionEquipoN3: (map['comision_equipo_n3'] ?? 0).toDouble(),
      bonoRango: (map['bono_rango'] ?? 0).toDouble(),
      bonoLiderazgo: (map['bono_liderazgo'] ?? 0).toDouble(),
      color: map['color'] ?? '#666666',
      icono: map['icono'] ?? 'star',
      insigniaUrl: map['insignia_url'],
      orden: map['orden'] ?? 0,
      activo: map['activo'] ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'negocio_id': negocioId,
    'codigo': codigo,
    'nombre': nombre,
    'descripcion': descripcion,
    'ventas_minimas_mes': ventasMinimasMes,
    'equipo_minimo': equipoMinimo,
    'puntos_minimos': puntosMinimos,
    'descuento_porcentaje': descuentoPorcentaje,
    'comision_ventas': comisionVentas,
    'comision_equipo_n1': comisionEquipoN1,
    'comision_equipo_n2': comisionEquipoN2,
    'comision_equipo_n3': comisionEquipoN3,
    'bono_rango': bonoRango,
    'bono_liderazgo': bonoLiderazgo,
    'color': color,
    'icono': icono,
    'insignia_url': insigniaUrl,
    'orden': orden,
    'activo': activo,
  };
}

// ═══════════════════════════════════════════════════════════════════════════════
// VENDEDORA / CONSULTORA
// ═══════════════════════════════════════════════════════════════════════════════

class NiceVendedora {
  final String id;
  final String? negocioId;
  final String? usuarioId;
  final String codigoVendedora;
  final String nombre;
  final String? apellidos;
  final String? email;
  final String? telefono;
  final String? whatsapp;
  final DateTime? fechaNacimiento;
  final String? direccion;
  final String? ciudad;
  final String? estado;
  final String? codigoPostal;
  final String? nivelId;
  final String? patrocinadoraId;
  final DateTime? fechaIngreso;
  final String? rfc;
  final String? curp;
  final String? banco;
  final String? clabe;
  final String? titularCuenta;
  final String? instagram;
  final String? facebook;
  final String? tiktok;
  final String? fotoUrl;
  final double ventasTotales;
  final double comisionesTotales;
  final int puntosAcumulados;
  final int clientesActivos;
  final int equipoDirecto;
  final bool activo;
  final bool verificada;
  final String? notas;
  final DateTime? createdAt;
  final String? authUid; // V10.22: Para vincular con cuenta de auth

  // Datos de relaciones
  final String? nivelCodigo;
  final String? nivelNombre;
  final String? nivelColor;
  final String? nivelIcono;
  final double? comisionVentas;
  final String? patrocinadoraNombre;
  final String? patrocinadoraCodigo;
  final double? ventasMes;
  final int? totalClientes;
  final int? pedidosPendientes;

  NiceVendedora({
    required this.id,
    this.negocioId,
    this.usuarioId,
    required this.codigoVendedora,
    required this.nombre,
    this.apellidos,
    this.email,
    this.telefono,
    this.whatsapp,
    this.fechaNacimiento,
    this.direccion,
    this.ciudad,
    this.estado,
    this.codigoPostal,
    this.nivelId,
    this.patrocinadoraId,
    this.fechaIngreso,
    this.rfc,
    this.curp,
    this.banco,
    this.clabe,
    this.titularCuenta,
    this.instagram,
    this.facebook,
    this.tiktok,
    this.fotoUrl,
    this.ventasTotales = 0,
    this.comisionesTotales = 0,
    this.puntosAcumulados = 0,
    this.clientesActivos = 0,
    this.equipoDirecto = 0,
    this.activo = true,
    this.verificada = false,
    this.notas,
    this.createdAt,
    this.authUid,
    this.nivelCodigo,
    this.nivelNombre,
    this.nivelColor,
    this.nivelIcono,
    this.comisionVentas,
    this.patrocinadoraNombre,
    this.patrocinadoraCodigo,
    this.ventasMes,
    this.totalClientes,
    this.pedidosPendientes,
  });

  String get nombreCompleto => '$nombre ${apellidos ?? ''}'.trim();

  factory NiceVendedora.fromMap(Map<String, dynamic> map) {
    return NiceVendedora(
      id: map['id'] ?? '',
      negocioId: map['negocio_id'],
      usuarioId: map['usuario_id'],
      codigoVendedora: map['codigo_vendedora'] ?? '',
      nombre: map['nombre'] ?? '',
      apellidos: map['apellidos'],
      email: map['email'],
      telefono: map['telefono'],
      whatsapp: map['whatsapp'],
      fechaNacimiento: map['fecha_nacimiento'] != null ? DateTime.parse(map['fecha_nacimiento']) : null,
      direccion: map['direccion'],
      ciudad: map['ciudad'],
      estado: map['estado'],
      codigoPostal: map['codigo_postal'],
      nivelId: map['nivel_id'],
      patrocinadoraId: map['patrocinadora_id'],
      fechaIngreso: map['fecha_ingreso'] != null ? DateTime.parse(map['fecha_ingreso']) : null,
      rfc: map['rfc'],
      curp: map['curp'],
      banco: map['banco'],
      clabe: map['clabe'],
      titularCuenta: map['titular_cuenta'],
      instagram: map['instagram'],
      facebook: map['facebook'],
      tiktok: map['tiktok'],
      fotoUrl: map['foto_url'],
      ventasTotales: (map['ventas_totales'] ?? 0).toDouble(),
      comisionesTotales: (map['comisiones_totales'] ?? 0).toDouble(),
      puntosAcumulados: map['puntos_acumulados'] ?? 0,
      clientesActivos: map['clientes_activos'] ?? 0,
      equipoDirecto: map['equipo_directo'] ?? 0,
      activo: map['activo'] ?? true,
      verificada: map['verificada'] ?? false,
      notas: map['notas'],
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
      authUid: map['auth_uid'],
      nivelCodigo: map['nivel_codigo'],
      nivelNombre: map['nivel_nombre'],
      nivelColor: map['nivel_color'],
      nivelIcono: map['nivel_icono'],
      comisionVentas: map['comision_ventas']?.toDouble(),
      patrocinadoraNombre: map['patrocinadora_nombre'],
      patrocinadoraCodigo: map['patrocinadora_codigo'],
      ventasMes: map['ventas_mes']?.toDouble(),
      totalClientes: map['total_clientes'],
      pedidosPendientes: map['pedidos_pendientes'],
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'negocio_id': negocioId,
    'usuario_id': usuarioId,
    'codigo_vendedora': codigoVendedora,
    'nombre': nombre,
    'apellidos': apellidos,
    'email': email,
    'telefono': telefono,
    'whatsapp': whatsapp,
    'fecha_nacimiento': fechaNacimiento?.toIso8601String().split('T')[0],
    'direccion': direccion,
    'ciudad': ciudad,
    'estado': estado,
    'codigo_postal': codigoPostal,
    'nivel_id': nivelId,
    'patrocinadora_id': patrocinadoraId,
    'fecha_ingreso': fechaIngreso?.toIso8601String().split('T')[0],
    'rfc': rfc,
    'curp': curp,
    'banco': banco,
    'clabe': clabe,
    'titular_cuenta': titularCuenta,
    'instagram': instagram,
    'facebook': facebook,
    'tiktok': tiktok,
    'foto_url': fotoUrl,
    'activo': activo,
    'verificada': verificada,
    'notas': notas,
    'auth_uid': authUid,
  };

  Map<String, dynamic> toMapForInsert() {
    final map = toMap();
    map.remove('id');
    map.remove('codigo_vendedora'); // Se genera automáticamente
    return map;
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CLIENTE
// ═══════════════════════════════════════════════════════════════════════════════

class NiceCliente {
  final String id;
  final String? negocioId;
  final String? vendedoraId;
  final String nombre;
  final String? apellidos;
  final String? email;
  final String? telefono;
  final String? whatsapp;
  final DateTime? fechaNacimiento;
  final String? direccion;
  final String? colonia;
  final String? ciudad;
  final String? estado;
  final String? codigoPostal;
  final String? referencias;
  final List<String> categoriasFavoritas;
  final String? tallaAnillo;
  final String? preferenciasColor;
  final String? notas;
  final double totalCompras;
  final int cantidadPedidos;
  final DateTime? ultimaCompra;
  final int puntosAcumulados;
  final bool aceptaWhatsapp;
  final bool aceptaEmail;
  final DateTime? fechaUltimoContacto;
  final bool activo;
  final bool esVip;
  final DateTime? createdAt;

  NiceCliente({
    required this.id,
    this.negocioId,
    this.vendedoraId,
    required this.nombre,
    this.apellidos,
    this.email,
    this.telefono,
    this.whatsapp,
    this.fechaNacimiento,
    this.direccion,
    this.colonia,
    this.ciudad,
    this.estado,
    this.codigoPostal,
    this.referencias,
    this.categoriasFavoritas = const [],
    this.tallaAnillo,
    this.preferenciasColor,
    this.notas,
    this.totalCompras = 0,
    this.cantidadPedidos = 0,
    this.ultimaCompra,
    this.puntosAcumulados = 0,
    this.aceptaWhatsapp = true,
    this.aceptaEmail = true,
    this.fechaUltimoContacto,
    this.activo = true,
    this.esVip = false,
    this.createdAt,
  });

  String get nombreCompleto => '$nombre ${apellidos ?? ''}'.trim();
  String get direccionCompleta => [direccion, colonia, ciudad, estado, codigoPostal]
      .where((e) => e != null && e.isNotEmpty).join(', ');
  
  // Alias de compatibilidad
  String? get vendedoraNombre => null; // Se llena desde la pantalla si se incluye join
  int get totalPedidos => cantidadPedidos;

  factory NiceCliente.fromMap(Map<String, dynamic> map) {
    List<String> categorias = [];
    if (map['categorias_favoritas'] != null && map['categorias_favoritas'] is List) {
      categorias = List<String>.from(map['categorias_favoritas']);
    }

    return NiceCliente(
      id: map['id'] ?? '',
      negocioId: map['negocio_id'],
      vendedoraId: map['vendedora_id'],
      nombre: map['nombre'] ?? '',
      apellidos: map['apellidos'],
      email: map['email'],
      telefono: map['telefono'],
      whatsapp: map['whatsapp'],
      fechaNacimiento: map['fecha_nacimiento'] != null ? DateTime.parse(map['fecha_nacimiento']) : null,
      direccion: map['direccion'],
      colonia: map['colonia'],
      ciudad: map['ciudad'],
      estado: map['estado'],
      codigoPostal: map['codigo_postal'],
      referencias: map['referencias'],
      categoriasFavoritas: categorias,
      tallaAnillo: map['talla_anillo'],
      preferenciasColor: map['preferencias_color'],
      notas: map['notas'],
      totalCompras: (map['total_compras'] ?? 0).toDouble(),
      cantidadPedidos: map['cantidad_pedidos'] ?? 0,
      ultimaCompra: map['ultima_compra'] != null ? DateTime.parse(map['ultima_compra']) : null,
      puntosAcumulados: map['puntos_acumulados'] ?? 0,
      aceptaWhatsapp: map['acepta_whatsapp'] ?? true,
      aceptaEmail: map['acepta_email'] ?? true,
      fechaUltimoContacto: map['fecha_ultimo_contacto'] != null ? DateTime.parse(map['fecha_ultimo_contacto']) : null,
      activo: map['activo'] ?? true,
      esVip: map['es_vip'] ?? false,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'negocio_id': negocioId,
    'vendedora_id': vendedoraId,
    'nombre': nombre,
    'apellidos': apellidos,
    'email': email,
    'telefono': telefono,
    'whatsapp': whatsapp,
    'fecha_nacimiento': fechaNacimiento?.toIso8601String().split('T')[0],
    'direccion': direccion,
    'colonia': colonia,
    'ciudad': ciudad,
    'estado': estado,
    'codigo_postal': codigoPostal,
    'referencias': referencias,
    'categorias_favoritas': categoriasFavoritas,
    'talla_anillo': tallaAnillo,
    'preferencias_color': preferenciasColor,
    'notas': notas,
    'acepta_whatsapp': aceptaWhatsapp,
    'acepta_email': aceptaEmail,
    'activo': activo,
    'es_vip': esVip,
  };

  Map<String, dynamic> toMapForInsert() {
    final map = toMap();
    map.remove('id');
    return map;
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PEDIDO
// ═══════════════════════════════════════════════════════════════════════════════

class NicePedido {
  final String id;
  final String? negocioId;
  final String? vendedoraId;
  final String? clienteId;
  final String? catalogoId;
  final String folio;
  final DateTime fechaPedido;
  final double subtotal;
  final double descuento;
  final double envio;
  final double total;
  final double gananciaVendedora;
  final int puntosGenerados;
  final String estado;
  final DateTime? fechaConfirmacion;
  final DateTime? fechaPago;
  final DateTime? fechaEnvio;
  final DateTime? fechaEntrega;
  final String? metodoPago;
  final String? referenciaPago;
  final String? comprobanteUrl;
  final bool pagado;
  final String tipoEnvio;
  final String? direccionEnvio;
  final String? guiaEnvio;
  final String? paqueteria;
  final String? clienteNombre;
  final String? clienteTelefono;
  final String? notasVendedora;
  final String? notasInternas;
  final DateTime? createdAt;

  // Datos de relaciones
  final String? vendedoraCodigo;
  final String? vendedoraNombre;
  final String? vendedoraTelefono;
  final String? clienteNombreCompleto;
  final String? clienteDireccion;
  final String? catalogoNombre;
  final int? totalItems;
  final int? totalPiezas;

  NicePedido({
    required this.id,
    this.negocioId,
    this.vendedoraId,
    this.clienteId,
    this.catalogoId,
    required this.folio,
    required this.fechaPedido,
    this.subtotal = 0,
    this.descuento = 0,
    this.envio = 0,
    this.total = 0,
    this.gananciaVendedora = 0,
    this.puntosGenerados = 0,
    this.estado = 'pendiente',
    this.fechaConfirmacion,
    this.fechaPago,
    this.fechaEnvio,
    this.fechaEntrega,
    this.metodoPago,
    this.referenciaPago,
    this.comprobanteUrl,
    this.pagado = false,
    this.tipoEnvio = 'recoger',
    this.direccionEnvio,
    this.guiaEnvio,
    this.paqueteria,
    this.clienteNombre,
    this.clienteTelefono,
    this.notasVendedora,
    this.notasInternas,
    this.createdAt,
    this.vendedoraCodigo,
    this.vendedoraNombre,
    this.vendedoraTelefono,
    this.clienteNombreCompleto,
    this.clienteDireccion,
    this.catalogoNombre,
    this.totalItems,
    this.totalPiezas,
  });

  factory NicePedido.fromMap(Map<String, dynamic> map) {
    return NicePedido(
      id: map['id'] ?? '',
      negocioId: map['negocio_id'],
      vendedoraId: map['vendedora_id'],
      clienteId: map['cliente_id'],
      catalogoId: map['catalogo_id'],
      folio: map['folio'] ?? '',
      fechaPedido: map['fecha_pedido'] != null 
          ? DateTime.parse(map['fecha_pedido']) 
          : DateTime.now(),
      subtotal: (map['subtotal'] ?? 0).toDouble(),
      descuento: (map['descuento'] ?? 0).toDouble(),
      envio: (map['envio'] ?? 0).toDouble(),
      total: (map['total'] ?? 0).toDouble(),
      gananciaVendedora: (map['ganancia_vendedora'] ?? 0).toDouble(),
      puntosGenerados: map['puntos_generados'] ?? 0,
      estado: map['estado'] ?? 'pendiente',
      fechaConfirmacion: map['fecha_confirmacion'] != null ? DateTime.parse(map['fecha_confirmacion']) : null,
      fechaPago: map['fecha_pago'] != null ? DateTime.parse(map['fecha_pago']) : null,
      fechaEnvio: map['fecha_envio'] != null
          ? DateTime.parse(map['fecha_envio'])
          : (map['fecha_entrega_estimada'] != null
              ? DateTime.parse(map['fecha_entrega_estimada'])
              : null),
      fechaEntrega: map['fecha_entrega'] != null
          ? DateTime.parse(map['fecha_entrega'])
          : (map['fecha_entrega_real'] != null
              ? DateTime.parse(map['fecha_entrega_real'])
              : null),
      metodoPago: map['metodo_pago'],
      referenciaPago: map['referencia_pago'],
      comprobanteUrl: map['comprobante_url'],
      pagado: map['pagado'] ?? false,
      tipoEnvio: map['tipo_envio'] ?? 'recoger',
      direccionEnvio: map['direccion_entrega'] ?? map['direccion_envio'],
      guiaEnvio: map['guia_envio'],
      paqueteria: map['paqueteria'],
      clienteNombre: map['cliente_nombre'],
      clienteTelefono: map['cliente_telefono'],
      notasVendedora: map['notas_vendedora'],
      notasInternas: map['notas_internas'],
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
      vendedoraCodigo: map['codigo_vendedora'],
      vendedoraNombre: map['vendedora_nombre'],
      vendedoraTelefono: map['vendedora_telefono'],
      clienteNombreCompleto: map['cliente_nombre'],
      clienteDireccion: map['cliente_direccion'],
      catalogoNombre: map['catalogo_nombre'],
      totalItems: map['total_items'],
      totalPiezas: map['total_piezas'],
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'negocio_id': negocioId,
    'vendedora_id': vendedoraId,
    'cliente_id': clienteId,
    'catalogo_id': catalogoId,
    'folio': folio,
    'fecha_pedido': fechaPedido.toIso8601String().split('T')[0],
    'subtotal': subtotal,
    'descuento': descuento,
    'envio': envio,
    'total': total,
    'estado': estado,
    'metodo_pago': metodoPago,
    'referencia_pago': referenciaPago,
    'comprobante_url': comprobanteUrl,
    'pagado': pagado,
    'tipo_envio': tipoEnvio,
    'direccion_entrega': direccionEnvio,
    'guia_envio': guiaEnvio,
    'paqueteria': paqueteria,
    'cliente_nombre': clienteNombre,
    'cliente_telefono': clienteTelefono,
    'notas_vendedora': notasVendedora,
    'notas_internas': notasInternas,
  };

  Map<String, dynamic> toMapForInsert() {
    final map = toMap();
    map.remove('id');
    map.remove('folio'); // Se genera automáticamente
    return map;
  }

  String get estadoDisplay {
    switch (estado) {
      case 'pendiente': return 'Pendiente';
      case 'confirmado': return 'Confirmado';
      case 'pagado': return 'Pagado';
      case 'enviado': return 'Enviado';
      case 'entregado': return 'Entregado';
      case 'cancelado': return 'Cancelado';
      default: return estado;
    }
  }
  
  // Aliases de compatibilidad
  String get folioPedido => folio;
  String? get notas => notasVendedora;
  List<NicePedidoItem> get items => []; // Se llena desde la pantalla
}

// ═══════════════════════════════════════════════════════════════════════════════
// ITEM DE PEDIDO
// ═══════════════════════════════════════════════════════════════════════════════

class NicePedidoItem {
  final String id;
  final String pedidoId;
  final String? productoId;
  final String? sku;
  final String nombreProducto;
  final int cantidad;
  final double precioUnitario;
  final double? precioVendedora;
  final double subtotal;
  final double ganancia;
  final String? talla;
  final String? color;
  final String? grabado;
  final bool disponible;
  final String? notas;

  NicePedidoItem({
    required this.id,
    required this.pedidoId,
    this.productoId,
    this.sku,
    required this.nombreProducto,
    this.cantidad = 1,
    required this.precioUnitario,
    this.precioVendedora,
    required this.subtotal,
    this.ganancia = 0,
    this.talla,
    this.color,
    this.grabado,
    this.disponible = true,
    this.notas,
  });

  factory NicePedidoItem.fromMap(Map<String, dynamic> map) {
    return NicePedidoItem(
      id: map['id'] ?? '',
      pedidoId: map['pedido_id'] ?? '',
      productoId: map['producto_id'],
      sku: map['sku'],
      nombreProducto: map['nombre_producto'] ?? '',
      cantidad: map['cantidad'] ?? 1,
      precioUnitario: (map['precio_unitario'] ?? 0).toDouble(),
      precioVendedora: map['precio_vendedora']?.toDouble(),
      subtotal: (map['subtotal'] ?? 0).toDouble(),
      ganancia: (map['ganancia'] ?? 0).toDouble(),
      talla: map['talla'],
      color: map['color'],
      grabado: map['grabado'],
      disponible: map['disponible'] ?? true,
      notas: map['notas'],
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'pedido_id': pedidoId,
    'producto_id': productoId,
    'sku': sku,
    'nombre_producto': nombreProducto,
    'cantidad': cantidad,
    'precio_unitario': precioUnitario,
    'precio_vendedora': precioVendedora,
    'subtotal': subtotal,
    'ganancia': ganancia,
    'talla': talla,
    'color': color,
    'grabado': grabado,
    'disponible': disponible,
    'notas': notas,
  };

  Map<String, dynamic> toMapForInsert() {
    final map = toMap();
    map.remove('id');
    return map;
  }
  
  // Alias de compatibilidad
  String get productoNombre => nombreProducto;
}

// ═══════════════════════════════════════════════════════════════════════════════
// COMISIÓN
// ═══════════════════════════════════════════════════════════════════════════════

class NiceComision {
  final String id;
  final String? negocioId;
  final String vendedoraId;
  final String? pedidoId;
  final String periodo;
  final DateTime fecha;
  final String tipo;
  final String? descripcion;
  final double baseCalculo;
  final double porcentaje;
  final double monto;
  final String? vendedoraOrigenId;
  final int nivelJerarquia;
  final String estado;
  final DateTime? fechaAprobacion;
  final DateTime? fechaPago;

  NiceComision({
    required this.id,
    this.negocioId,
    required this.vendedoraId,
    this.pedidoId,
    required this.periodo,
    required this.fecha,
    required this.tipo,
    this.descripcion,
    this.baseCalculo = 0,
    this.porcentaje = 0,
    required this.monto,
    this.vendedoraOrigenId,
    this.nivelJerarquia = 0,
    this.estado = 'pendiente',
    this.fechaAprobacion,
    this.fechaPago,
  });

  factory NiceComision.fromMap(Map<String, dynamic> map) {
    final fechaRaw = map['fecha'] ?? map['created_at'];
    DateTime fechaParsed;
    try {
      fechaParsed = fechaRaw != null ? DateTime.parse(fechaRaw) : DateTime.now();
    } catch (_) {
      fechaParsed = DateTime.now();
    }
    return NiceComision(
      id: map['id'] ?? '',
      negocioId: map['negocio_id'],
      vendedoraId: map['vendedora_id'] ?? '',
      pedidoId: map['pedido_id'],
      periodo: map['periodo'] ?? fechaParsed.toIso8601String().substring(0, 7),
      fecha: fechaParsed,
      tipo: map['tipo'] ?? '',
      descripcion: map['descripcion'],
      baseCalculo: (map['base_calculo'] ?? map['pedido_total'] ?? 0).toDouble(),
      porcentaje: (map['porcentaje'] ?? 0).toDouble(),
      monto: (map['monto'] ?? 0).toDouble(),
      vendedoraOrigenId: map['vendedora_origen_id'],
      nivelJerarquia: map['nivel_jerarquia'] ?? 0,
      estado: map['estado'] ?? 'pendiente',
      fechaAprobacion: map['fecha_aprobacion'] != null ? DateTime.parse(map['fecha_aprobacion']) : null,
      fechaPago: map['fecha_pago'] != null ? DateTime.parse(map['fecha_pago']) : null,
    );
  }

  String get tipoDisplay {
    switch (tipo) {
      case 'venta_directa': return 'Venta Directa';
      case 'equipo_n1': return 'Equipo Nivel 1';
      case 'equipo_n2': return 'Equipo Nivel 2';
      case 'equipo_n3': return 'Equipo Nivel 3';
      case 'bono_rango': return 'Bono de Rango';
      case 'bono_meta': return 'Bono de Meta';
      default: return tipo;
    }
  }
}
