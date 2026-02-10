/// ═══════════════════════════════════════════════════════════════════════════════
/// MODELOS PARA FORMULARIO QR CLIMAS - Robert Darin Platform
/// Sistema de solicitudes públicas y chat en tiempo real
/// ═══════════════════════════════════════════════════════════════════════════════

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MODELO: Solicitud desde QR (Lead público)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class ClimasSolicitudQrModel {
  final String id;
  final String? negocioId;
  
  // Datos personales
  final String nombreCompleto;
  final String telefono;
  final String? email;
  
  // Ubicación
  final String direccion;
  final String? colonia;
  final String? ciudad;
  final String? codigoPostal;
  final String? referenciaUbicacion;
  final double? latitud;
  final double? longitud;
  
  // Tipo de servicio
  final String tipoServicio;
  
  // Equipo actual
  final bool tieneEquipoActual;
  final String? marcaEquipoActual;
  final String? modeloEquipoActual;
  final int? capacidadBtuActual;
  final String? antiguedadEquipo;
  final String? problemaReportado;
  
  // Instalación nueva
  final String? tipoEspacio;
  final double? metrosCuadrados;
  final int cantidadEquiposDeseados;
  final String? presupuestoEstimado;
  
  // Preferencias
  final String? horarioContactoPreferido;
  final String medioContactoPreferido;
  final String? disponibilidadVisita;
  
  // Fotos y notas
  final List<String> fotos;
  final String? notasCliente;
  
  // Estado y seguimiento
  final String estado;
  final String? revisadoPor;
  final DateTime? fechaRevision;
  final String? notasInternas;
  final String? motivoRechazo;
  
  // Conversión
  final String? clienteCreadoId;
  final String? ordenCreadaId;
  final DateTime? fechaConversion;
  
  // Token para seguimiento público
  final String? tokenSeguimiento;
  
  // Metadatos
  final String? fuente;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ClimasSolicitudQrModel({
    required this.id,
    this.negocioId,
    required this.nombreCompleto,
    required this.telefono,
    this.email,
    required this.direccion,
    this.colonia,
    this.ciudad,
    this.codigoPostal,
    this.referenciaUbicacion,
    this.latitud,
    this.longitud,
    this.tipoServicio = 'cotizacion',
    this.tieneEquipoActual = false,
    this.marcaEquipoActual,
    this.modeloEquipoActual,
    this.capacidadBtuActual,
    this.antiguedadEquipo,
    this.problemaReportado,
    this.tipoEspacio,
    this.metrosCuadrados,
    this.cantidadEquiposDeseados = 1,
    this.presupuestoEstimado,
    this.horarioContactoPreferido,
    this.medioContactoPreferido = 'telefono',
    this.disponibilidadVisita,
    this.fotos = const [],
    this.notasCliente,
    this.estado = 'nueva',
    this.revisadoPor,
    this.fechaRevision,
    this.notasInternas,
    this.motivoRechazo,
    this.clienteCreadoId,
    this.ordenCreadaId,
    this.fechaConversion,
    this.tokenSeguimiento,
    this.fuente,
    this.createdAt,
    this.updatedAt,
  });

  factory ClimasSolicitudQrModel.fromMap(Map<String, dynamic> map) {
    return ClimasSolicitudQrModel(
      id: map['id'] ?? '',
      negocioId: map['negocio_id'],
      nombreCompleto: map['nombre_completo'] ?? '',
      telefono: map['telefono'] ?? '',
      email: map['email'],
      direccion: map['direccion'] ?? '',
      colonia: map['colonia'],
      ciudad: map['ciudad'],
      codigoPostal: map['codigo_postal'],
      referenciaUbicacion: map['referencia_ubicacion'],
      latitud: map['latitud'] != null ? (map['latitud'] as num).toDouble() : null,
      longitud: map['longitud'] != null ? (map['longitud'] as num).toDouble() : null,
      tipoServicio: map['tipo_servicio'] ?? 'cotizacion',
      tieneEquipoActual: map['tiene_equipo_actual'] ?? false,
      marcaEquipoActual: map['marca_equipo_actual'],
      modeloEquipoActual: map['modelo_equipo_actual'],
      capacidadBtuActual: map['capacidad_btu_actual'],
      antiguedadEquipo: map['antiguedad_equipo'],
      problemaReportado: map['problema_reportado'],
      tipoEspacio: map['tipo_espacio'],
      metrosCuadrados: map['metros_cuadrados'] != null ? (map['metros_cuadrados'] as num).toDouble() : null,
      cantidadEquiposDeseados: map['cantidad_equipos_deseados'] ?? 1,
      presupuestoEstimado: map['presupuesto_estimado'],
      horarioContactoPreferido: map['horario_contacto_preferido'],
      medioContactoPreferido: map['medio_contacto_preferido'] ?? 'telefono',
      disponibilidadVisita: map['disponibilidad_visita'],
      fotos: map['fotos'] != null ? List<String>.from(map['fotos']) : [],
      notasCliente: map['notas_cliente'],
      estado: map['estado'] ?? 'nueva',
      revisadoPor: map['revisado_por'],
      fechaRevision: map['fecha_revision'] != null ? DateTime.parse(map['fecha_revision']) : null,
      notasInternas: map['notas_internas'],
      motivoRechazo: map['motivo_rechazo'],
      clienteCreadoId: map['cliente_creado_id'],
      ordenCreadaId: map['orden_creada_id'],
      fechaConversion: map['fecha_conversion'] != null ? DateTime.parse(map['fecha_conversion']) : null,
      tokenSeguimiento: map['token_seguimiento'],
      fuente: map['fuente'],
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
    );
  }

  Map<String, dynamic> toMapForInsert() => {
    'negocio_id': negocioId,
    'nombre_completo': nombreCompleto,
    'telefono': telefono,
    'email': email,
    'direccion': direccion,
    'colonia': colonia,
    'ciudad': ciudad,
    'codigo_postal': codigoPostal,
    'referencia_ubicacion': referenciaUbicacion,
    'latitud': latitud,
    'longitud': longitud,
    'tipo_servicio': tipoServicio,
    'tiene_equipo_actual': tieneEquipoActual,
    'marca_equipo_actual': marcaEquipoActual,
    'modelo_equipo_actual': modeloEquipoActual,
    'capacidad_btu_actual': capacidadBtuActual,
    'antiguedad_equipo': antiguedadEquipo,
    'problema_reportado': problemaReportado,
    'tipo_espacio': tipoEspacio,
    'metros_cuadrados': metrosCuadrados,
    'cantidad_equipos_deseados': cantidadEquiposDeseados,
    'presupuesto_estimado': presupuestoEstimado,
    'horario_contacto_preferido': horarioContactoPreferido,
    'medio_contacto_preferido': medioContactoPreferido,
    'disponibilidad_visita': disponibilidadVisita,
    'fotos': fotos,
    'notas_cliente': notasCliente,
    'fuente': fuente ?? 'qr_tarjeta',
  };

  // Helpers para UI
  String get estadoDisplay {
    switch (estado) {
      case 'nueva': return 'Nueva';
      case 'revisando': return 'En Revisión';
      case 'contactado': return 'Contactado';
      case 'agendado': return 'Agendado';
      case 'aprobado': return 'Aprobado';
      case 'rechazado': return 'Rechazado';
      case 'convertido': return 'Convertido';
      default: return estado;
    }
  }

  String get tipoServicioDisplay {
    switch (tipoServicio) {
      case 'cotizacion': return 'Cotización';
      case 'instalacion': return 'Instalación';
      case 'mantenimiento': return 'Mantenimiento';
      case 'reparacion': return 'Reparación';
      case 'emergencia': return '🚨 Emergencia';
      default: return tipoServicio;
    }
  }

  String get tipoEspacioDisplay {
    switch (tipoEspacio) {
      case 'recamara': return 'Recámara';
      case 'sala': return 'Sala / Estancia';
      case 'oficina': return 'Oficina';
      case 'local_comercial': return 'Local Comercial';
      case 'bodega': return 'Bodega / Nave';
      default: return tipoEspacio ?? '';
    }
  }

  bool get esUrgente => tipoServicio == 'emergencia';
  bool get estaAprobado => estado == 'aprobado' || estado == 'convertido';
  bool get estaRechazado => estado == 'rechazado';
  bool get estaPendiente => estado == 'nueva' || estado == 'revisando';
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MODELO: Chat de Solicitud
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class ClimasChatMensajeModel {
  final String id;
  final String solicitudId;
  final bool esCliente;
  final String? remitenteId;
  final String remitenteNombre;
  final String mensaje;
  final String tipoMensaje;
  final String? adjuntoUrl;
  final String? adjuntoNombre;
  final bool leido;
  final DateTime? fechaLeido;
  final DateTime? createdAt;

  ClimasChatMensajeModel({
    required this.id,
    required this.solicitudId,
    required this.esCliente,
    this.remitenteId,
    required this.remitenteNombre,
    required this.mensaje,
    this.tipoMensaje = 'texto',
    this.adjuntoUrl,
    this.adjuntoNombre,
    this.leido = false,
    this.fechaLeido,
    this.createdAt,
  });

  factory ClimasChatMensajeModel.fromMap(Map<String, dynamic> map) {
    return ClimasChatMensajeModel(
      id: map['id'] ?? '',
      solicitudId: map['solicitud_id'] ?? '',
      esCliente: map['es_cliente'] ?? true,
      remitenteId: map['remitente_id'],
      remitenteNombre: map['remitente_nombre'] ?? '',
      mensaje: map['mensaje'] ?? '',
      tipoMensaje: map['tipo_mensaje'] ?? 'texto',
      adjuntoUrl: map['adjunto_url'],
      adjuntoNombre: map['adjunto_nombre'],
      leido: map['leido'] ?? false,
      fechaLeido: map['fecha_leido'] != null ? DateTime.parse(map['fecha_leido']) : null,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
    );
  }

  Map<String, dynamic> toMapForInsert() => {
    'solicitud_id': solicitudId,
    'es_cliente': esCliente,
    'remitente_id': remitenteId,
    'remitente_nombre': remitenteNombre,
    'mensaje': mensaje,
    'tipo_mensaje': tipoMensaje,
    'adjunto_url': adjuntoUrl,
    'adjunto_nombre': adjuntoNombre,
  };
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MODELO: Catálogo de Servicios Públicos
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class ClimasCatalogoServicioModel {
  final String id;
  final String? negocioId;
  final String? codigo;
  final String nombre;
  final String? descripcion;
  final String? icono;
  final double? precioDesde;
  final double? precioHasta;
  final bool mostrarPrecio;
  final String? tiempoEstimado;
  final String categoria;
  final bool enPromocion;
  final double? precioPromocion;
  final String? textoPromocion;
  final int orden;
  final bool activo;

  ClimasCatalogoServicioModel({
    required this.id,
    this.negocioId,
    this.codigo,
    required this.nombre,
    this.descripcion,
    this.icono,
    this.precioDesde,
    this.precioHasta,
    this.mostrarPrecio = true,
    this.tiempoEstimado,
    this.categoria = 'general',
    this.enPromocion = false,
    this.precioPromocion,
    this.textoPromocion,
    this.orden = 0,
    this.activo = true,
  });

  factory ClimasCatalogoServicioModel.fromMap(Map<String, dynamic> map) {
    return ClimasCatalogoServicioModel(
      id: map['id'] ?? '',
      negocioId: map['negocio_id'],
      codigo: map['codigo'],
      nombre: map['nombre'] ?? '',
      descripcion: map['descripcion'],
      icono: map['icono'],
      precioDesde: map['precio_desde'] != null ? (map['precio_desde'] as num).toDouble() : null,
      precioHasta: map['precio_hasta'] != null ? (map['precio_hasta'] as num).toDouble() : null,
      mostrarPrecio: map['mostrar_precio'] ?? true,
      tiempoEstimado: map['tiempo_estimado'],
      categoria: map['categoria'] ?? 'general',
      enPromocion: map['en_promocion'] ?? false,
      precioPromocion: map['precio_promocion'] != null ? (map['precio_promocion'] as num).toDouble() : null,
      textoPromocion: map['texto_promocion'],
      orden: map['orden'] ?? 0,
      activo: map['activo'] ?? true,
    );
  }

  String get rangoPrecio {
    if (!mostrarPrecio || precioDesde == null) return 'Consultar';
    if (precioHasta == null || precioDesde == precioHasta) {
      return '\$${precioDesde!.toStringAsFixed(0)}';
    }
    return '\$${precioDesde!.toStringAsFixed(0)} - \$${precioHasta!.toStringAsFixed(0)}';
  }

  String get categoriaDisplay {
    switch (categoria) {
      case 'instalacion': return 'Instalación';
      case 'mantenimiento': return 'Mantenimiento';
      case 'reparacion': return 'Reparación';
      case 'emergencia': return 'Emergencia';
      default: return 'General';
    }
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MODELO: Configuración del Formulario QR
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class ClimasConfigFormularioModel {
  final String id;
  final String? negocioId;
  final String? logoUrl;
  final String colorPrimario;
  final String colorSecundario;
  final String mensajeBienvenida;
  final bool campoEmailRequerido;
  final bool campoDireccionRequerido;
  final bool campoFotosHabilitado;
  final int maxFotos;
  final List<String> serviciosHabilitados;
  final String? notificarEmail;
  final String? notificarWhatsapp;
  final bool notificarPush;
  final String? avisoPrivacidadUrl;
  final String? terminosCondicionesUrl;
  final bool formularioActivo;
  final String? mensajeFormularioInactivo;

  ClimasConfigFormularioModel({
    required this.id,
    this.negocioId,
    this.logoUrl,
    this.colorPrimario = '#00D9FF',
    this.colorSecundario = '#8B5CF6',
    this.mensajeBienvenida = '¡Bienvenido!',
    this.campoEmailRequerido = false,
    this.campoDireccionRequerido = true,
    this.campoFotosHabilitado = true,
    this.maxFotos = 5,
    this.serviciosHabilitados = const ['cotizacion', 'instalacion', 'mantenimiento', 'reparacion'],
    this.notificarEmail,
    this.notificarWhatsapp,
    this.notificarPush = true,
    this.avisoPrivacidadUrl,
    this.terminosCondicionesUrl,
    this.formularioActivo = true,
    this.mensajeFormularioInactivo,
  });

  factory ClimasConfigFormularioModel.fromMap(Map<String, dynamic> map) {
    return ClimasConfigFormularioModel(
      id: map['id'] ?? '',
      negocioId: map['negocio_id'],
      logoUrl: map['logo_url'],
      colorPrimario: map['color_primario'] ?? '#00D9FF',
      colorSecundario: map['color_secundario'] ?? '#8B5CF6',
      mensajeBienvenida: map['mensaje_bienvenida'] ?? '¡Bienvenido!',
      campoEmailRequerido: map['campo_email_requerido'] ?? false,
      campoDireccionRequerido: map['campo_direccion_requerido'] ?? true,
      campoFotosHabilitado: map['campo_fotos_habilitado'] ?? true,
      maxFotos: map['max_fotos'] ?? 5,
      serviciosHabilitados: map['servicios_habilitados'] != null
          ? List<String>.from(map['servicios_habilitados'])
          : ['cotizacion', 'instalacion', 'mantenimiento', 'reparacion'],
      notificarEmail: map['notificar_email'],
      notificarWhatsapp: map['notificar_whatsapp'],
      notificarPush: map['notificar_push'] ?? true,
      avisoPrivacidadUrl: map['aviso_privacidad_url'],
      terminosCondicionesUrl: map['terminos_condiciones_url'],
      formularioActivo: map['formulario_activo'] ?? true,
      mensajeFormularioInactivo: map['mensaje_formulario_inactivo'],
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MODELO: Historial de Solicitud
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class ClimasSolicitudHistorialModel {
  final String id;
  final String solicitudId;
  final String? estadoAnterior;
  final String estadoNuevo;
  final String? comentario;
  final String? usuarioId;
  final String? usuarioNombre;
  final DateTime? createdAt;

  ClimasSolicitudHistorialModel({
    required this.id,
    required this.solicitudId,
    this.estadoAnterior,
    required this.estadoNuevo,
    this.comentario,
    this.usuarioId,
    this.usuarioNombre,
    this.createdAt,
  });

  factory ClimasSolicitudHistorialModel.fromMap(Map<String, dynamic> map) {
    return ClimasSolicitudHistorialModel(
      id: map['id'] ?? '',
      solicitudId: map['solicitud_id'] ?? '',
      estadoAnterior: map['estado_anterior'],
      estadoNuevo: map['estado_nuevo'] ?? '',
      comentario: map['comentario'],
      usuarioId: map['usuario_id'],
      usuarioNombre: map['usuario_nombre'],
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
    );
  }
}
