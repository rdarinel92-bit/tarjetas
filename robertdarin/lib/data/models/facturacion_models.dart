import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// MODELOS DE FACTURACIÓN ELECTRÓNICA (CFDI 4.0)
// Robert Darin Platform v10.13
// ═══════════════════════════════════════════════════════════════════════════════

/// Emisor de facturas (datos fiscales del negocio)
class FacturacionEmisorModel {
  final String id;
  final String negocioId;
  final String rfc;
  final String razonSocial;
  final String? nombreComercial;
  final String regimenFiscal;
  final String? regimenFiscalDescripcion;
  
  // Dirección
  final String? calle;
  final String? numeroExterior;
  final String? numeroInterior;
  final String? colonia;
  final String codigoPostal;
  final String? municipio;
  final String? estado;
  final String pais;
  
  // Certificados
  final String? certificadoCer;
  final String? certificadoKey;
  final String? certificadoPassword;
  final String? certificadoNumero;
  final DateTime? certificadoFechaInicio;
  final DateTime? certificadoFechaFin;
  
  // API
  final String proveedorApi;
  final String? apiKey;
  final String? apiSecret;
  final bool modoPruebas;
  
  // Personalización
  final String? logoUrl;
  final String colorPrimario;
  
  // Folios
  final String serieFacturas;
  final int folioActualFacturas;
  final String serieNotasCredito;
  final int folioActualNc;
  
  // Configuración
  final bool enviarEmailAutomatico;
  final bool incluirPdf;
  final bool activo;
  
  final DateTime createdAt;
  final DateTime updatedAt;

  FacturacionEmisorModel({
    required this.id,
    required this.negocioId,
    required this.rfc,
    required this.razonSocial,
    this.nombreComercial,
    required this.regimenFiscal,
    this.regimenFiscalDescripcion,
    this.calle,
    this.numeroExterior,
    this.numeroInterior,
    this.colonia,
    required this.codigoPostal,
    this.municipio,
    this.estado,
    this.pais = 'México',
    this.certificadoCer,
    this.certificadoKey,
    this.certificadoPassword,
    this.certificadoNumero,
    this.certificadoFechaInicio,
    this.certificadoFechaFin,
    this.proveedorApi = 'facturapi',
    this.apiKey,
    this.apiSecret,
    this.modoPruebas = true,
    this.logoUrl,
    this.colorPrimario = '#1E3A8A',
    this.serieFacturas = 'A',
    this.folioActualFacturas = 1,
    this.serieNotasCredito = 'NC',
    this.folioActualNc = 1,
    this.enviarEmailAutomatico = true,
    this.incluirPdf = true,
    this.activo = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FacturacionEmisorModel.fromMap(Map<String, dynamic> map) {
    return FacturacionEmisorModel(
      id: map['id'] ?? '',
      negocioId: map['negocio_id'] ?? '',
      rfc: map['rfc'] ?? '',
      razonSocial: map['razon_social'] ?? '',
      nombreComercial: map['nombre_comercial'],
      regimenFiscal: map['regimen_fiscal'] ?? '',
      regimenFiscalDescripcion: map['regimen_fiscal_descripcion'],
      calle: map['calle'],
      numeroExterior: map['numero_exterior'],
      numeroInterior: map['numero_interior'],
      colonia: map['colonia'],
      codigoPostal: map['codigo_postal'] ?? '',
      municipio: map['municipio'],
      estado: map['estado'],
      pais: map['pais'] ?? 'México',
      certificadoCer: map['certificado_cer'],
      certificadoKey: map['certificado_key'],
      certificadoPassword: map['certificado_password'],
      certificadoNumero: map['certificado_numero'],
      certificadoFechaInicio: map['certificado_fecha_inicio'] != null
          ? DateTime.parse(map['certificado_fecha_inicio'])
          : null,
      certificadoFechaFin: map['certificado_fecha_fin'] != null
          ? DateTime.parse(map['certificado_fecha_fin'])
          : null,
      proveedorApi: map['proveedor_api'] ?? 'facturapi',
      apiKey: map['api_key'],
      apiSecret: map['api_secret'],
      modoPruebas: map['modo_pruebas'] == true,
      logoUrl: map['logo_url'],
      colorPrimario: map['color_primario'] ?? '#1E3A8A',
      serieFacturas: map['serie_facturas'] ?? 'A',
      folioActualFacturas: map['folio_actual_facturas'] ?? 1,
      serieNotasCredito: map['serie_notas_credito'] ?? 'NC',
      folioActualNc: map['folio_actual_nc'] ?? 1,
      enviarEmailAutomatico: map['enviar_email_automatico'] ?? true,
      incluirPdf: map['incluir_pdf'] ?? true,
      activo: map['activo'] ?? true,
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(map['updated_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toMapForInsert() => {
    'negocio_id': negocioId,
    'rfc': rfc,
    'razon_social': razonSocial,
    'nombre_comercial': nombreComercial,
    'regimen_fiscal': regimenFiscal,
    'regimen_fiscal_descripcion': regimenFiscalDescripcion,
    'calle': calle,
    'numero_exterior': numeroExterior,
    'numero_interior': numeroInterior,
    'colonia': colonia,
    'codigo_postal': codigoPostal,
    'municipio': municipio,
    'estado': estado,
    'pais': pais,
    'proveedor_api': proveedorApi,
    'api_key': apiKey,
    'api_secret': apiSecret,
    'modo_pruebas': modoPruebas,
    'logo_url': logoUrl,
    'color_primario': colorPrimario,
    'serie_facturas': serieFacturas,
    'serie_notas_credito': serieNotasCredito,
    'enviar_email_automatico': enviarEmailAutomatico,
    'incluir_pdf': incluirPdf,
    'activo': activo,
  };

  String get direccionCompleta {
    final parts = <String>[];
    if (calle != null) parts.add(calle!);
    if (numeroExterior != null) parts.add('#$numeroExterior');
    if (numeroInterior != null) parts.add('Int. $numeroInterior');
    if (colonia != null) parts.add(colonia!);
    if (codigoPostal.isNotEmpty) parts.add('C.P. $codigoPostal');
    if (municipio != null) parts.add(municipio!);
    if (estado != null) parts.add(estado!);
    return parts.join(', ');
  }

  bool get certificadoVigente {
    if (certificadoFechaFin == null) return false;
    return certificadoFechaFin!.isAfter(DateTime.now());
  }
}

/// Cliente fiscal (receptor de facturas)
class FacturacionClienteModel {
  final String id;
  final String negocioId;
  final String? clienteFintechId;
  final String? clienteClimasId;
  final String? clienteVentasId;
  final String? clientePurificadoraId;
  
  final String rfc;
  final String razonSocial;
  final String regimenFiscal;
  final String usoCfdi;
  
  final String? calle;
  final String? numeroExterior;
  final String? numeroInterior;
  final String? colonia;
  final String codigoPostal;
  final String? municipio;
  final String? estado;
  final String pais;
  
  final String? email;
  final String? telefono;
  
  final String? numRegIdTrib;
  final String? residenciaFiscal;
  
  final bool activo;
  final DateTime createdAt;
  final DateTime updatedAt;

  FacturacionClienteModel({
    required this.id,
    required this.negocioId,
    this.clienteFintechId,
    this.clienteClimasId,
    this.clienteVentasId,
    this.clientePurificadoraId,
    required this.rfc,
    required this.razonSocial,
    required this.regimenFiscal,
    this.usoCfdi = 'G03',
    this.calle,
    this.numeroExterior,
    this.numeroInterior,
    this.colonia,
    required this.codigoPostal,
    this.municipio,
    this.estado,
    this.pais = 'México',
    this.email,
    this.telefono,
    this.numRegIdTrib,
    this.residenciaFiscal,
    this.activo = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FacturacionClienteModel.fromMap(Map<String, dynamic> map) {
    return FacturacionClienteModel(
      id: map['id'] ?? '',
      negocioId: map['negocio_id'] ?? '',
      clienteFintechId: map['cliente_fintech_id'],
      clienteClimasId: map['cliente_climas_id'],
      clienteVentasId: map['cliente_ventas_id'],
      clientePurificadoraId: map['cliente_purificadora_id'],
      rfc: map['rfc'] ?? '',
      razonSocial: map['razon_social'] ?? '',
      regimenFiscal: map['regimen_fiscal'] ?? '',
      usoCfdi: map['uso_cfdi'] ?? 'G03',
      calle: map['calle'],
      numeroExterior: map['numero_exterior'],
      numeroInterior: map['numero_interior'],
      colonia: map['colonia'],
      codigoPostal: map['codigo_postal'] ?? '',
      municipio: map['municipio'],
      estado: map['estado'],
      pais: map['pais'] ?? 'México',
      email: map['email'],
      telefono: map['telefono'],
      numRegIdTrib: map['num_reg_id_trib'],
      residenciaFiscal: map['residencia_fiscal'],
      activo: map['activo'] ?? true,
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(map['updated_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toMapForInsert() => {
    'negocio_id': negocioId,
    'cliente_fintech_id': clienteFintechId,
    'cliente_climas_id': clienteClimasId,
    'cliente_ventas_id': clienteVentasId,
    'cliente_purificadora_id': clientePurificadoraId,
    'rfc': rfc,
    'razon_social': razonSocial,
    'regimen_fiscal': regimenFiscal,
    'uso_cfdi': usoCfdi,
    'calle': calle,
    'numero_exterior': numeroExterior,
    'numero_interior': numeroInterior,
    'colonia': colonia,
    'codigo_postal': codigoPostal,
    'municipio': municipio,
    'estado': estado,
    'pais': pais,
    'email': email,
    'telefono': telefono,
    'num_reg_id_trib': numRegIdTrib,
    'residencia_fiscal': residenciaFiscal,
    'activo': activo,
  };

  bool get esExtranjero => rfc == 'XEXX010101000';
  bool get esPublicoGeneral => rfc == 'XAXX010101000';
}

/// Factura (CFDI)
class FacturaModel {
  final String id;
  final String negocioId;
  final String? emisorId;
  final String? clienteFiscalId;
  
  final String? serie;
  final int? folio;
  final String? uuidFiscal;
  
  final String tipoComprobante;
  
  final DateTime fechaEmision;
  final DateTime? fechaTimbrado;
  final DateTime? fechaCancelacion;
  
  final String? moduloOrigen;
  final String? referenciaOrigenId;
  final String? referenciaTipo;
  
  final double subtotal;
  final double descuento;
  final double iva;
  final double isrRetenido;
  final double ivaRetenido;
  final double total;
  
  final String formaPago;
  final String metodoPago;
  final String moneda;
  final double tipoCambio;
  
  final String usoCfdi;
  final String? lugarExpedicion;
  
  final String estado;
  final String? motivoCancelacion;
  final String? uuidSustitucion;
  
  final String? xmlUrl;
  final String? pdfUrl;
  final String? xmlContent;
  
  final Map<String, dynamic>? pacResponse;
  final String? cadenaOriginal;
  final String? selloCfdi;
  final String? selloSat;
  final String? certificadoSat;
  
  final String? notas;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Campos de la vista (join)
  final String? emisorRfc;
  final String? emisorRazonSocial;
  final String? clienteRfc;
  final String? clienteRazonSocial;
  final String? clienteEmail;

  FacturaModel({
    required this.id,
    required this.negocioId,
    this.emisorId,
    this.clienteFiscalId,
    this.serie,
    this.folio,
    this.uuidFiscal,
    this.tipoComprobante = 'I',
    required this.fechaEmision,
    this.fechaTimbrado,
    this.fechaCancelacion,
    this.moduloOrigen,
    this.referenciaOrigenId,
    this.referenciaTipo,
    this.subtotal = 0,
    this.descuento = 0,
    this.iva = 0,
    this.isrRetenido = 0,
    this.ivaRetenido = 0,
    this.total = 0,
    this.formaPago = '99',
    this.metodoPago = 'PUE',
    this.moneda = 'MXN',
    this.tipoCambio = 1,
    this.usoCfdi = 'G03',
    this.lugarExpedicion,
    this.estado = 'borrador',
    this.motivoCancelacion,
    this.uuidSustitucion,
    this.xmlUrl,
    this.pdfUrl,
    this.xmlContent,
    this.pacResponse,
    this.cadenaOriginal,
    this.selloCfdi,
    this.selloSat,
    this.certificadoSat,
    this.notas,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.emisorRfc,
    this.emisorRazonSocial,
    this.clienteRfc,
    this.clienteRazonSocial,
    this.clienteEmail,
  });

  factory FacturaModel.fromMap(Map<String, dynamic> map) {
    return FacturaModel(
      id: map['id'] ?? '',
      negocioId: map['negocio_id'] ?? '',
      emisorId: map['emisor_id'],
      clienteFiscalId: map['cliente_fiscal_id'],
      serie: map['serie'],
      folio: map['folio'],
      uuidFiscal: map['uuid_fiscal'],
      tipoComprobante: map['tipo_comprobante'] ?? 'I',
      fechaEmision: DateTime.parse(map['fecha_emision'] ?? DateTime.now().toIso8601String()),
      fechaTimbrado: map['fecha_timbrado'] != null ? DateTime.parse(map['fecha_timbrado']) : null,
      fechaCancelacion: map['fecha_cancelacion'] != null ? DateTime.parse(map['fecha_cancelacion']) : null,
      moduloOrigen: map['modulo_origen'],
      referenciaOrigenId: map['referencia_origen_id'],
      referenciaTipo: map['referencia_tipo'],
      subtotal: (map['subtotal'] ?? 0).toDouble(),
      descuento: (map['descuento'] ?? 0).toDouble(),
      iva: (map['iva'] ?? 0).toDouble(),
      isrRetenido: (map['isr_retenido'] ?? 0).toDouble(),
      ivaRetenido: (map['iva_retenido'] ?? 0).toDouble(),
      total: (map['total'] ?? 0).toDouble(),
      formaPago: map['forma_pago'] ?? '99',
      metodoPago: map['metodo_pago'] ?? 'PUE',
      moneda: map['moneda'] ?? 'MXN',
      tipoCambio: (map['tipo_cambio'] ?? 1).toDouble(),
      usoCfdi: map['uso_cfdi'] ?? 'G03',
      lugarExpedicion: map['lugar_expedicion'],
      estado: map['estado'] ?? 'borrador',
      motivoCancelacion: map['motivo_cancelacion'],
      uuidSustitucion: map['uuid_sustitucion'],
      xmlUrl: map['xml_url'],
      pdfUrl: map['pdf_url'],
      xmlContent: map['xml_content'],
      pacResponse: map['pac_response'],
      cadenaOriginal: map['cadena_original'],
      selloCfdi: map['sello_cfdi'],
      selloSat: map['sello_sat'],
      certificadoSat: map['certificado_sat'],
      notas: map['notas'],
      createdBy: map['created_by'],
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(map['updated_at'] ?? DateTime.now().toIso8601String()),
      emisorRfc: map['emisor_rfc'],
      emisorRazonSocial: map['emisor_razon_social'],
      clienteRfc: map['cliente_rfc'],
      clienteRazonSocial: map['cliente_razon_social'],
      clienteEmail: map['cliente_email'],
    );
  }

  Map<String, dynamic> toMapForInsert() => {
    'negocio_id': negocioId,
    'emisor_id': emisorId,
    'cliente_fiscal_id': clienteFiscalId,
    'serie': serie,
    'folio': folio,
    'tipo_comprobante': tipoComprobante,
    'fecha_emision': fechaEmision.toIso8601String(),
    'modulo_origen': moduloOrigen,
    'referencia_origen_id': referenciaOrigenId,
    'referencia_tipo': referenciaTipo,
    'subtotal': subtotal,
    'descuento': descuento,
    'iva': iva,
    'isr_retenido': isrRetenido,
    'iva_retenido': ivaRetenido,
    'total': total,
    'forma_pago': formaPago,
    'metodo_pago': metodoPago,
    'moneda': moneda,
    'tipo_cambio': tipoCambio,
    'uso_cfdi': usoCfdi,
    'lugar_expedicion': lugarExpedicion,
    'estado': estado,
    'notas': notas,
    'created_by': createdBy,
  };

  String get numeroFactura => '${serie ?? 'A'}-${folio?.toString().padLeft(6, '0') ?? '000000'}';
  
  String get tipoComprobanteDisplay {
    switch (tipoComprobante) {
      case 'I': return 'Ingreso';
      case 'E': return 'Egreso';
      case 'T': return 'Traslado';
      case 'N': return 'Nómina';
      case 'P': return 'Pago';
      default: return tipoComprobante;
    }
  }

  String get estadoDisplay {
    switch (estado) {
      case 'borrador': return 'Borrador';
      case 'pendiente': return 'Pendiente';
      case 'timbrada': return 'Timbrada';
      case 'enviada': return 'Enviada';
      case 'cancelada': return 'Cancelada';
      default: return estado;
    }
  }

  Color get estadoColor {
    switch (estado) {
      case 'borrador': return Colors.grey;
      case 'pendiente': return Colors.orange;
      case 'timbrada': return Colors.green;
      case 'enviada': return Colors.blue;
      case 'cancelada': return Colors.red;
      default: return Colors.grey;
    }
  }

  bool get estaTimbrada => uuidFiscal != null && uuidFiscal!.isNotEmpty;
  bool get estaCancelada => estado == 'cancelada';
  bool get puedeModificarse => estado == 'borrador';
  bool get puedeCancelarse => estaTimbrada && !estaCancelada;
}

/// Concepto de factura
class FacturaConceptoModel {
  final String id;
  final String facturaId;
  final String claveProdServ;
  final String claveUnidad;
  final String? unidad;
  final String descripcion;
  final String? noIdentificacion;
  final double cantidad;
  final double valorUnitario;
  final double descuento;
  final double importe;
  final String objetoImp;
  final DateTime createdAt;

  FacturaConceptoModel({
    required this.id,
    required this.facturaId,
    required this.claveProdServ,
    required this.claveUnidad,
    this.unidad,
    required this.descripcion,
    this.noIdentificacion,
    this.cantidad = 1,
    this.valorUnitario = 0,
    this.descuento = 0,
    this.importe = 0,
    this.objetoImp = '02',
    required this.createdAt,
  });

  factory FacturaConceptoModel.fromMap(Map<String, dynamic> map) {
    return FacturaConceptoModel(
      id: map['id'] ?? '',
      facturaId: map['factura_id'] ?? '',
      claveProdServ: map['clave_prod_serv'] ?? '',
      claveUnidad: map['clave_unidad'] ?? '',
      unidad: map['unidad'],
      descripcion: map['descripcion'] ?? '',
      noIdentificacion: map['no_identificacion'],
      cantidad: (map['cantidad'] ?? 1).toDouble(),
      valorUnitario: (map['valor_unitario'] ?? 0).toDouble(),
      descuento: (map['descuento'] ?? 0).toDouble(),
      importe: (map['importe'] ?? 0).toDouble(),
      objetoImp: map['objeto_imp'] ?? '02',
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toMapForInsert() => {
    'factura_id': facturaId,
    'clave_prod_serv': claveProdServ,
    'clave_unidad': claveUnidad,
    'unidad': unidad,
    'descripcion': descripcion,
    'no_identificacion': noIdentificacion,
    'cantidad': cantidad,
    'valor_unitario': valorUnitario,
    'descuento': descuento,
    'importe': importe,
    'objeto_imp': objetoImp,
  };
}

/// Régimen fiscal del catálogo SAT
class RegimenFiscalModel {
  final String clave;
  final String descripcion;
  final bool aplicaPersonaFisica;
  final bool aplicaPersonaMoral;
  final bool activo;

  RegimenFiscalModel({
    required this.clave,
    required this.descripcion,
    this.aplicaPersonaFisica = true,
    this.aplicaPersonaMoral = true,
    this.activo = true,
  });

  factory RegimenFiscalModel.fromMap(Map<String, dynamic> map) {
    return RegimenFiscalModel(
      clave: map['clave'] ?? '',
      descripcion: map['descripcion'] ?? '',
      aplicaPersonaFisica: map['aplica_persona_fisica'] ?? true,
      aplicaPersonaMoral: map['aplica_persona_moral'] ?? true,
      activo: map['activo'] ?? true,
    );
  }

  String get display => '$clave - $descripcion';
}

/// Uso de CFDI del catálogo SAT
class UsoCfdiModel {
  final String clave;
  final String descripcion;
  final bool aplicaPersonaFisica;
  final bool aplicaPersonaMoral;

  UsoCfdiModel({
    required this.clave,
    required this.descripcion,
    this.aplicaPersonaFisica = true,
    this.aplicaPersonaMoral = true,
  });

  factory UsoCfdiModel.fromMap(Map<String, dynamic> map) {
    return UsoCfdiModel(
      clave: map['clave'] ?? '',
      descripcion: map['descripcion'] ?? '',
      aplicaPersonaFisica: map['aplica_persona_fisica'] ?? true,
      aplicaPersonaMoral: map['aplica_persona_moral'] ?? true,
    );
  }

  String get display => '$clave - $descripcion';
}

/// Forma de pago del catálogo SAT
class FormaPagoModel {
  final String clave;
  final String descripcion;

  FormaPagoModel({
    required this.clave,
    required this.descripcion,
  });

  factory FormaPagoModel.fromMap(Map<String, dynamic> map) {
    return FormaPagoModel(
      clave: map['clave'] ?? '',
      descripcion: map['descripcion'] ?? '',
    );
  }

  String get display => '$clave - $descripcion';
}

/// Producto/servicio frecuente para facturación
class FacturacionProductoModel {
  final String id;
  final String? negocioId;
  final String claveProdServ;
  final String claveUnidad;
  final String? unidad;
  final String descripcion;
  final double precioUnitario;
  final double ivaTasa;
  final double isrRetencion;
  final double ivaRetencion;
  final String? modulo;
  final bool activo;
  final DateTime createdAt;
  final DateTime updatedAt;

  FacturacionProductoModel({
    required this.id,
    this.negocioId,
    required this.claveProdServ,
    required this.claveUnidad,
    this.unidad,
    required this.descripcion,
    this.precioUnitario = 0,
    this.ivaTasa = 0.16,
    this.isrRetencion = 0,
    this.ivaRetencion = 0,
    this.modulo,
    this.activo = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FacturacionProductoModel.fromMap(Map<String, dynamic> map) {
    return FacturacionProductoModel(
      id: map['id'] ?? '',
      negocioId: map['negocio_id'],
      claveProdServ: map['clave_prod_serv'] ?? '',
      claveUnidad: map['clave_unidad'] ?? '',
      unidad: map['unidad'],
      descripcion: map['descripcion'] ?? '',
      precioUnitario: (map['precio_unitario'] ?? 0).toDouble(),
      ivaTasa: (map['iva_tasa'] ?? 0.16).toDouble(),
      isrRetencion: (map['isr_retencion'] ?? 0).toDouble(),
      ivaRetencion: (map['iva_retencion'] ?? 0).toDouble(),
      modulo: map['modulo'],
      activo: map['activo'] ?? true,
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(map['updated_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toMapForInsert() => {
    'negocio_id': negocioId,
    'clave_prod_serv': claveProdServ,
    'clave_unidad': claveUnidad,
    'unidad': unidad,
    'descripcion': descripcion,
    'precio_unitario': precioUnitario,
    'iva_tasa': ivaTasa,
    'isr_retencion': isrRetencion,
    'iva_retencion': ivaRetencion,
    'modulo': modulo,
    'activo': activo,
  };
}
