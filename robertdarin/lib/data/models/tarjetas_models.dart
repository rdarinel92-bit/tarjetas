// ═══════════════════════════════════════════════════════════════════════════════
// MODELOS DE TARJETAS VIRTUALES
// Robert Darin Platform v10.14
// ═══════════════════════════════════════════════════════════════════════════════

/// Configuración del proveedor de tarjetas
class TarjetasConfigModel {
  final String id;
  final String negocioId;
  final String proveedor; // pomelo, rapyd, stripe, galileo
  final String? apiKey;
  final String? apiSecret;
  final String? webhookSecret;
  final String? apiBaseUrl;
  final String? webhookUrl;
  final String? accountId;
  final String? programId;
  final bool modoPruebas;
  final double limiteDiarioDefault;
  final double limiteMensualDefault;
  final double limiteTransaccionDefault;
  final String tipoTarjetaDefault;
  final String redDefault;
  final String monedaDefault;
  final String nombrePrograma;
  final String? logoUrl;
  final String colorTarjeta;
  final bool activo;
  final bool verificado;
  final DateTime? fechaVerificacion;
  final DateTime createdAt;

  TarjetasConfigModel({
    required this.id,
    required this.negocioId,
    required this.proveedor,
    this.apiKey,
    this.apiSecret,
    this.webhookSecret,
    this.apiBaseUrl,
    this.webhookUrl,
    this.accountId,
    this.programId,
    this.modoPruebas = true,
    this.limiteDiarioDefault = 10000.0,
    this.limiteMensualDefault = 50000.0,
    this.limiteTransaccionDefault = 5000.0,
    this.tipoTarjetaDefault = 'virtual',
    this.redDefault = 'visa',
    this.monedaDefault = 'MXN',
    this.nombrePrograma = 'Robert Darin Cards',
    this.logoUrl,
    this.colorTarjeta = '#1E3A8A',
    this.activo = false,
    this.verificado = false,
    this.fechaVerificacion,
    required this.createdAt,
  });

  factory TarjetasConfigModel.fromMap(Map<String, dynamic> map) {
    return TarjetasConfigModel(
      id: map['id'] ?? '',
      negocioId: map['negocio_id'] ?? '',
      proveedor: map['proveedor'] ?? 'pomelo',
      apiKey: map['api_key'],
      apiSecret: map['api_secret'],
      webhookSecret: map['webhook_secret'],
      apiBaseUrl: map['api_base_url'],
      webhookUrl: map['webhook_url'],
      accountId: map['account_id'],
      programId: map['program_id'],
      modoPruebas: map['modo_pruebas'] == true,
      limiteDiarioDefault: (map['limite_diario_default'] ?? 10000).toDouble(),
      limiteMensualDefault: (map['limite_mensual_default'] ?? 50000).toDouble(),
      limiteTransaccionDefault: (map['limite_transaccion_default'] ?? 5000).toDouble(),
      tipoTarjetaDefault: map['tipo_tarjeta_default'] ?? 'virtual',
      redDefault: map['red_default'] ?? 'visa',
      monedaDefault: map['moneda_default'] ?? 'MXN',
      nombrePrograma: map['nombre_programa'] ?? 'Robert Darin Cards',
      logoUrl: map['logo_url'],
      colorTarjeta: map['color_tarjeta'] ?? '#1E3A8A',
      activo: map['activo'] ?? false,
      verificado: map['verificado'] ?? false,
      fechaVerificacion: map['fecha_verificacion'] != null 
          ? DateTime.parse(map['fecha_verificacion']) 
          : null,
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toMapForInsert() => {
    'negocio_id': negocioId,
    'proveedor': proveedor,
    'api_key': apiKey,
    'api_secret': apiSecret,
    'webhook_secret': webhookSecret,
    'api_base_url': apiBaseUrl,
    'webhook_url': webhookUrl,
    'account_id': accountId,
    'program_id': programId,
    'modo_pruebas': modoPruebas,
    'limite_diario_default': limiteDiarioDefault,
    'limite_mensual_default': limiteMensualDefault,
    'limite_transaccion_default': limiteTransaccionDefault,
    'tipo_tarjeta_default': tipoTarjetaDefault,
    'red_default': redDefault,
    'moneda_default': monedaDefault,
    'nombre_programa': nombrePrograma,
    'logo_url': logoUrl,
    'color_tarjeta': colorTarjeta,
    'activo': activo,
    'verificado': verificado,
  };

  bool get tieneCredenciales => apiKey != null && apiKey!.isNotEmpty;
  
  String get proveedorNombre {
    switch (proveedor) {
      case 'pomelo': return 'Pomelo';
      case 'rapyd': return 'Rapyd';
      case 'stripe': return 'Stripe Issuing';
      case 'galileo': return 'Galileo';
      default: return proveedor;
    }
  }
}

/// Titular de tarjeta (con KYC)
class TarjetaTitularModel {
  final String id;
  final String negocioId;
  final String? usuarioId;
  final String? clienteId;
  final String? empleadoId;
  final String? externalId;
  final String tipoPersona;
  final String nombre;
  final String? apellidoPaterno;
  final String? apellidoMaterno;
  final String? razonSocial;
  final String? curp;
  final String? rfc;
  final String? ineClave;
  final String email;
  final String telefono;
  final String? calle;
  final String? numeroExterior;
  final String? numeroInterior;
  final String? colonia;
  final String? codigoPostal;
  final String? municipio;
  final String? estado;
  final String pais;
  final DateTime? fechaNacimiento;
  final String? lugarNacimiento;
  final String nacionalidad;
  final String kycStatus;
  final int kycNivel;
  final DateTime? kycFechaAprobacion;
  final String? kycMotivoRechazo;
  final String? documentoIneFrontalUrl;
  final String? documentoIneReversoUrl;
  final String? documentoComprobanteDomicilioUrl;
  final String? selfieUrl;
  final bool activo;
  final bool bloqueado;
  final String? motivoBloqueo;
  final DateTime createdAt;

  TarjetaTitularModel({
    required this.id,
    required this.negocioId,
    this.usuarioId,
    this.clienteId,
    this.empleadoId,
    this.externalId,
    this.tipoPersona = 'fisica',
    required this.nombre,
    this.apellidoPaterno,
    this.apellidoMaterno,
    this.razonSocial,
    this.curp,
    this.rfc,
    this.ineClave,
    required this.email,
    required this.telefono,
    this.calle,
    this.numeroExterior,
    this.numeroInterior,
    this.colonia,
    this.codigoPostal,
    this.municipio,
    this.estado,
    this.pais = 'México',
    this.fechaNacimiento,
    this.lugarNacimiento,
    this.nacionalidad = 'Mexicana',
    this.kycStatus = 'pendiente',
    this.kycNivel = 0,
    this.kycFechaAprobacion,
    this.kycMotivoRechazo,
    this.documentoIneFrontalUrl,
    this.documentoIneReversoUrl,
    this.documentoComprobanteDomicilioUrl,
    this.selfieUrl,
    this.activo = true,
    this.bloqueado = false,
    this.motivoBloqueo,
    required this.createdAt,
  });

  factory TarjetaTitularModel.fromMap(Map<String, dynamic> map) {
    return TarjetaTitularModel(
      id: map['id'] ?? '',
      negocioId: map['negocio_id'] ?? '',
      usuarioId: map['usuario_id'],
      clienteId: map['cliente_id'],
      empleadoId: map['empleado_id'],
      externalId: map['external_id'],
      tipoPersona: map['tipo_persona'] ?? 'fisica',
      nombre: map['nombre'] ?? map['nombre_completo'] ?? '',
      apellidoPaterno: map['apellido_paterno'],
      apellidoMaterno: map['apellido_materno'],
      razonSocial: map['razon_social'],
      curp: map['curp'],
      rfc: map['rfc'],
      ineClave: map['ine_clave'],
      email: map['email'] ?? '',
      telefono: map['telefono'] ?? '',
      calle: map['calle'],
      numeroExterior: map['numero_exterior'],
      numeroInterior: map['numero_interior'],
      colonia: map['colonia'],
      codigoPostal: map['codigo_postal'],
      municipio: map['municipio'],
      estado: map['estado'],
      pais: map['pais'] ?? 'México',
      fechaNacimiento: map['fecha_nacimiento'] != null 
          ? DateTime.parse(map['fecha_nacimiento']) 
          : null,
      lugarNacimiento: map['lugar_nacimiento'],
      nacionalidad: map['nacionalidad'] ?? 'Mexicana',
      kycStatus: map['kyc_status'] ?? 'pendiente',
      kycNivel: map['kyc_nivel'] ?? 0,
      kycFechaAprobacion: map['kyc_fecha_aprobacion'] != null 
          ? DateTime.parse(map['kyc_fecha_aprobacion']) 
          : null,
      kycMotivoRechazo: map['kyc_motivo_rechazo'],
      documentoIneFrontalUrl: map['documento_ine_frontal_url'],
      documentoIneReversoUrl: map['documento_ine_reverso_url'],
      documentoComprobanteDomicilioUrl: map['documento_comprobante_domicilio_url'],
      selfieUrl: map['selfie_url'],
      activo: map['activo'] ?? true,
      bloqueado: map['bloqueado'] ?? false,
      motivoBloqueo: map['motivo_bloqueo'],
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toMapForInsert() {
    final direccion = [
      calle,
      numeroExterior,
      numeroInterior,
      colonia,
    ].whereType<String>().where((p) => p.isNotEmpty).join(' ');

    return {
      'negocio_id': negocioId,
      'usuario_id': usuarioId,
      'cliente_id': clienteId,
      'empleado_id': empleadoId,
      'tipo_persona': tipoPersona,
      'nombre': nombre,
      'apellido_paterno': apellidoPaterno,
      'apellido_materno': apellidoMaterno,
      'razon_social': razonSocial,
      'curp': curp,
      'rfc': rfc,
      'ine_clave': ineClave,
      'email': email,
      'telefono': telefono,
      'calle': calle,
      'numero_exterior': numeroExterior,
      'numero_interior': numeroInterior,
      'colonia': colonia,
      'codigo_postal': codigoPostal,
      'municipio': municipio,
      'ciudad': municipio,
      'estado': estado,
      'pais': pais,
      'fecha_nacimiento': fechaNacimiento?.toIso8601String().split('T')[0],
      'lugar_nacimiento': lugarNacimiento,
      'nacionalidad': nacionalidad,
      'nombre_completo': nombreCompleto,
      'direccion': direccion.isEmpty ? null : direccion,
    };
  }

  String get nombreCompleto {
    final partes = [nombre];
    if (apellidoPaterno != null) partes.add(apellidoPaterno!);
    if (apellidoMaterno != null) partes.add(apellidoMaterno!);
    return partes.join(' ');
  }

  String get kycStatusTexto {
    switch (kycStatus) {
      case 'pendiente': return 'Pendiente';
      case 'en_revision': return 'En Revisión';
      case 'aprobado': return 'Aprobado';
      case 'rechazado': return 'Rechazado';
      default: return kycStatus;
    }
  }

  int get kycStatusColor {
    switch (kycStatus) {
      case 'aprobado': return 0xFF10B981;
      case 'en_revision': return 0xFFFBBF24;
      case 'rechazado': return 0xFFEF4444;
      default: return 0xFF6B7280;
    }
  }
}

/// Tarjeta Virtual
class TarjetaVirtualModel {
  final String id;
  final String negocioId;
  final String titularId;
  final String? externalCardId;
  final String? numeroTarjetaMasked;
  final String? ultimos4Digitos;
  final String? fechaExpiracion;
  final String tipo;
  final String red;
  final String categoria;
  final String? nombreTarjeta;
  final String moneda;
  final double saldoDisponible;
  final double saldoRetenido;
  final double limiteDiario;
  final double limiteMensual;
  final double limiteTransaccion;
  final double usoDiario;
  final double usoMensual;
  final bool soloNacional;
  final bool permitirEcommerce;
  final bool permitirAtm;
  final bool permitirInternacional;
  final String estado;
  final String? motivoBloqueo;
  final DateTime? fechaBloqueo;
  final String? etiqueta;
  final String? notas;
  final DateTime createdAt;
  final DateTime? expiresAt;
  
  // Datos del titular (de la vista)
  final String? titularNombre;
  final String? titularApellido;
  final String? titularEmail;
  final String? titularTelefono;
  final String? titularKycStatus;

  TarjetaVirtualModel({
    required this.id,
    required this.negocioId,
    required this.titularId,
    this.externalCardId,
    this.numeroTarjetaMasked,
    this.ultimos4Digitos,
    this.fechaExpiracion,
    this.tipo = 'virtual',
    this.red = 'visa',
    this.categoria = 'debito',
    this.nombreTarjeta,
    this.moneda = 'MXN',
    this.saldoDisponible = 0,
    this.saldoRetenido = 0,
    this.limiteDiario = 10000,
    this.limiteMensual = 50000,
    this.limiteTransaccion = 5000,
    this.usoDiario = 0,
    this.usoMensual = 0,
    this.soloNacional = false,
    this.permitirEcommerce = true,
    this.permitirAtm = false,
    this.permitirInternacional = true,
    this.estado = 'activa',
    this.motivoBloqueo,
    this.fechaBloqueo,
    this.etiqueta,
    this.notas,
    required this.createdAt,
    this.expiresAt,
    this.titularNombre,
    this.titularApellido,
    this.titularEmail,
    this.titularTelefono,
    this.titularKycStatus,
  });

  factory TarjetaVirtualModel.fromMap(Map<String, dynamic> map) {
    return TarjetaVirtualModel(
      id: map['id'] ?? '',
      negocioId: map['negocio_id'] ?? '',
      titularId: map['titular_id'] ?? '',
      externalCardId: map['external_card_id'],
      numeroTarjetaMasked: map['numero_tarjeta_masked'],
      ultimos4Digitos: map['ultimos_4_digitos'],
      fechaExpiracion: map['fecha_expiracion'],
      tipo: map['tipo'] ?? 'virtual',
      red: map['red'] ?? 'visa',
      categoria: map['categoria'] ?? 'debito',
      nombreTarjeta: map['nombre_tarjeta'],
      moneda: map['moneda'] ?? 'MXN',
      saldoDisponible: (map['saldo_disponible'] ?? 0).toDouble(),
      saldoRetenido: (map['saldo_retenido'] ?? 0).toDouble(),
      limiteDiario: (map['limite_diario'] ?? 10000).toDouble(),
      limiteMensual: (map['limite_mensual'] ?? 50000).toDouble(),
      limiteTransaccion: (map['limite_transaccion'] ?? 5000).toDouble(),
      usoDiario: (map['uso_diario'] ?? 0).toDouble(),
      usoMensual: (map['uso_mensual'] ?? 0).toDouble(),
      soloNacional: map['solo_nacional'] ?? false,
      permitirEcommerce: map['permitir_ecommerce'] ?? true,
      permitirAtm: map['permitir_atm'] ?? false,
      permitirInternacional: map['permitir_internacional'] ?? true,
      estado: map['estado'] ?? 'activa',
      motivoBloqueo: map['motivo_bloqueo'],
      fechaBloqueo: map['fecha_bloqueo'] != null 
          ? DateTime.parse(map['fecha_bloqueo']) 
          : null,
      etiqueta: map['etiqueta'],
      notas: map['notas'],
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
      expiresAt: map['expires_at'] != null 
          ? DateTime.parse(map['expires_at']) 
          : null,
      // Datos de la vista
      titularNombre: map['titular_nombre'],
      titularApellido: map['titular_apellido'],
      titularEmail: map['titular_email'],
      titularTelefono: map['titular_telefono'],
      titularKycStatus: map['titular_kyc_status'],
    );
  }

  Map<String, dynamic> toMapForInsert() => {
    'negocio_id': negocioId,
    'titular_id': titularId,
    'tipo': tipo,
    'red': red,
    'categoria': categoria,
    'nombre_tarjeta': nombreTarjeta,
    'moneda': moneda,
    'limite_diario': limiteDiario,
    'limite_mensual': limiteMensual,
    'limite_transaccion': limiteTransaccion,
    'solo_nacional': soloNacional,
    'permitir_ecommerce': permitirEcommerce,
    'permitir_atm': permitirAtm,
    'permitir_internacional': permitirInternacional,
    'etiqueta': etiqueta,
    'notas': notas,
  };

  String get estadoTexto {
    switch (estado) {
      case 'pendiente': return 'Pendiente';
      case 'activa': return 'Activa';
      case 'bloqueada': return 'Bloqueada';
      case 'cancelada': return 'Cancelada';
      case 'expirada': return 'Expirada';
      default: return estado;
    }
  }

  int get estadoColor {
    switch (estado) {
      case 'activa': return 0xFF10B981;
      case 'pendiente': return 0xFFFBBF24;
      case 'bloqueada': return 0xFFEF4444;
      case 'cancelada': return 0xFF6B7280;
      case 'expirada': return 0xFF6B7280;
      default: return 0xFF6B7280;
    }
  }

  String get redIcono {
    switch (red.toLowerCase()) {
      case 'visa': return '💳';
      case 'mastercard': return '🔴';
      default: return '💳';
    }
  }

  String get tipoTexto => tipo == 'virtual' ? 'Virtual' : 'Física';

  double get limiteRestanteDiario => limiteDiario - usoDiario;
  double get limiteRestanteMensual => limiteMensual - usoMensual;
  
  String get titularNombreCompleto {
    if (titularNombre == null) return '';
    return '${titularNombre ?? ''} ${titularApellido ?? ''}'.trim();
  }
}

/// Transacción de tarjeta
class TarjetaTransaccionModel {
  final String id;
  final String negocioId;
  final String tarjetaId;
  final String? externalTransactionId;
  final String tipo;
  final String estado;
  final double monto;
  final double? montoOriginal;
  final String moneda;
  final String? monedaOriginal;
  final double? tipoCambio;
  final String? comercioNombre;
  final String? comercioId;
  final String? comercioCategoria;
  final String? comercioCiudad;
  final String? comercioPais;
  final String? codigoAutorizacion;
  final String? referencia;
  final String? motivoRechazo;
  final String? codigoRechazo;
  final double? saldoAnterior;
  final double? saldoPosterior;
  final DateTime fechaTransaccion;
  final DateTime? fechaLiquidacion;
  final DateTime createdAt;
  
  // Datos de la vista
  final String? numeroTarjetaMasked;
  final String? nombreTarjeta;
  final String? tarjetaEtiqueta;
  final String? titularNombre;
  final String? titularEmail;

  TarjetaTransaccionModel({
    required this.id,
    required this.negocioId,
    required this.tarjetaId,
    this.externalTransactionId,
    required this.tipo,
    this.estado = 'pendiente',
    required this.monto,
    this.montoOriginal,
    this.moneda = 'MXN',
    this.monedaOriginal,
    this.tipoCambio,
    this.comercioNombre,
    this.comercioId,
    this.comercioCategoria,
    this.comercioCiudad,
    this.comercioPais,
    this.codigoAutorizacion,
    this.referencia,
    this.motivoRechazo,
    this.codigoRechazo,
    this.saldoAnterior,
    this.saldoPosterior,
    required this.fechaTransaccion,
    this.fechaLiquidacion,
    required this.createdAt,
    this.numeroTarjetaMasked,
    this.nombreTarjeta,
    this.tarjetaEtiqueta,
    this.titularNombre,
    this.titularEmail,
  });

  factory TarjetaTransaccionModel.fromMap(Map<String, dynamic> map) {
    return TarjetaTransaccionModel(
      id: map['id'] ?? '',
      negocioId: map['negocio_id'] ?? '',
      tarjetaId: map['tarjeta_id'] ?? '',
      externalTransactionId: map['external_transaction_id'],
      tipo: map['tipo'] ?? '',
      estado: map['estado'] ?? 'pendiente',
      monto: (map['monto'] ?? 0).toDouble(),
      montoOriginal: map['monto_original']?.toDouble(),
      moneda: map['moneda'] ?? 'MXN',
      monedaOriginal: map['moneda_original'],
      tipoCambio: map['tipo_cambio']?.toDouble(),
      comercioNombre: map['comercio_nombre'],
      comercioId: map['comercio_id'],
      comercioCategoria: map['comercio_categoria'],
      comercioCiudad: map['comercio_ciudad'],
      comercioPais: map['comercio_pais'],
      codigoAutorizacion: map['codigo_autorizacion'],
      referencia: map['referencia'],
      motivoRechazo: map['motivo_rechazo'],
      codigoRechazo: map['codigo_rechazo'],
      saldoAnterior: map['saldo_anterior']?.toDouble(),
      saldoPosterior: map['saldo_posterior']?.toDouble(),
      fechaTransaccion: DateTime.parse(map['fecha_transaccion'] ?? DateTime.now().toIso8601String()),
      fechaLiquidacion: map['fecha_liquidacion'] != null 
          ? DateTime.parse(map['fecha_liquidacion']) 
          : null,
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
      // Vista
      numeroTarjetaMasked: map['numero_tarjeta_masked'],
      nombreTarjeta: map['nombre_tarjeta'],
      tarjetaEtiqueta: map['tarjeta_etiqueta'],
      titularNombre: map['titular_nombre'],
      titularEmail: map['titular_email'],
    );
  }

  String get tipoTexto {
    switch (tipo) {
      case 'compra': return 'Compra';
      case 'devolucion': return 'Devolución';
      case 'recarga': return 'Recarga';
      case 'retiro_atm': return 'Retiro ATM';
      case 'transferencia': return 'Transferencia';
      case 'ajuste': return 'Ajuste';
      default: return tipo;
    }
  }

  String get tipoIcono {
    switch (tipo) {
      case 'compra': return '🛒';
      case 'devolucion': return '↩️';
      case 'recarga': return '💰';
      case 'retiro_atm': return '🏧';
      case 'transferencia': return '↔️';
      case 'ajuste': return '⚙️';
      default: return '💳';
    }
  }

  int get estadoColor {
    switch (estado) {
      case 'completada': return 0xFF10B981;
      case 'autorizada': return 0xFF3B82F6;
      case 'pendiente': return 0xFFFBBF24;
      case 'rechazada': return 0xFFEF4444;
      case 'revertida': return 0xFF6B7280;
      default: return 0xFF6B7280;
    }
  }

  bool get esGasto => tipo == 'compra' || tipo == 'retiro_atm';
  bool get esIngreso => tipo == 'devolucion' || tipo == 'recarga';
}

/// Alerta de tarjeta
class TarjetaAlertaModel {
  final String id;
  final String negocioId;
  final String? tarjetaId;
  final String? titularId;
  final String tipo;
  final String titulo;
  final String? mensaje;
  final String? transaccionId;
  final bool leida;
  final DateTime? fechaLeida;
  final DateTime createdAt;

  TarjetaAlertaModel({
    required this.id,
    required this.negocioId,
    this.tarjetaId,
    this.titularId,
    required this.tipo,
    required this.titulo,
    this.mensaje,
    this.transaccionId,
    this.leida = false,
    this.fechaLeida,
    required this.createdAt,
  });

  factory TarjetaAlertaModel.fromMap(Map<String, dynamic> map) {
    return TarjetaAlertaModel(
      id: map['id'] ?? '',
      negocioId: map['negocio_id'] ?? '',
      tarjetaId: map['tarjeta_id'],
      titularId: map['titular_id'],
      tipo: map['tipo'] ?? '',
      titulo: map['titulo'] ?? '',
      mensaje: map['mensaje'],
      transaccionId: map['transaccion_id'],
      leida: map['leida'] ?? false,
      fechaLeida: map['fecha_leida'] != null 
          ? DateTime.parse(map['fecha_leida']) 
          : null,
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  String get tipoIcono {
    switch (tipo) {
      case 'transaccion': return '💳';
      case 'limite_cercano': return '⚠️';
      case 'bloqueo': return '🔒';
      case 'recarga': return '💰';
      case 'fraude': return '🚨';
      default: return '🔔';
    }
  }
}
