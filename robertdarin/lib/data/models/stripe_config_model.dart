/// ═══════════════════════════════════════════════════════════════════════════════
/// MODELO: Configuración de Stripe por Negocio
/// Robert Darin Fintech V10.7
/// ═══════════════════════════════════════════════════════════════════════════════

class StripeConfigModel {
  final String id;
  final String negocioId;
  final String? stripeAccountId;
  final String? stripePublicKey;
  final String? stripeSecretKey;
  final String? webhookSecret;
  final bool modoProduccion;
  final bool activo;
  final bool linkPagoHabilitado;
  final bool domiciliacionHabilitada;
  final bool oxxoHabilitado;
  final bool speiHabilitado;
  final String comisionManejo; // 'absorber', 'cliente', 'dividir'
  final bool cobrarComisionCliente;
  final double porcentajeComision;
  final bool notificarPagoExitoso;
  final bool notificarPagoFallido;
  final bool permitirTarjeta;
  final bool permitirOxxo;
  final bool permitirSpei;
  final DateTime createdAt;

  StripeConfigModel({
    required this.id,
    required this.negocioId,
    this.stripeAccountId,
    this.stripePublicKey,
    this.stripeSecretKey,
    this.webhookSecret,
    this.modoProduccion = false,
    this.activo = true,
    this.linkPagoHabilitado = true,
    this.domiciliacionHabilitada = false,
    this.oxxoHabilitado = false,
    this.speiHabilitado = true,
    this.comisionManejo = 'absorber',
    this.cobrarComisionCliente = false,
    this.porcentajeComision = 3.6,
    this.notificarPagoExitoso = true,
    this.notificarPagoFallido = true,
    this.permitirTarjeta = true,
    this.permitirOxxo = false,
    this.permitirSpei = true,
    required this.createdAt,
  });

  factory StripeConfigModel.fromMap(Map<String, dynamic> map) {
    return StripeConfigModel(
      id: map['id'] ?? '',
      negocioId: map['negocio_id'] ?? '',
      stripeAccountId: map['stripe_account_id'],
      stripePublicKey: map['stripe_public_key'],
      stripeSecretKey: map['stripe_secret_key'],
      webhookSecret: map['webhook_secret'],
      modoProduccion: map['modo_produccion'] ?? false,
      activo: map['activo'] ?? true,
      linkPagoHabilitado: map['link_pago_habilitado'] ?? true,
      domiciliacionHabilitada: map['domiciliacion_habilitada'] ?? false,
      oxxoHabilitado: map['oxxo_habilitado'] ?? false,
      speiHabilitado: map['spei_habilitado'] ?? true,
      comisionManejo: map['comision_manejo'] ?? 'absorber',
      cobrarComisionCliente: map['cobrar_comision_cliente'] ?? false,
      porcentajeComision: (map['porcentaje_comision'] as num?)?.toDouble() ?? 3.6,
      notificarPagoExitoso: map['notificar_pago_exitoso'] ?? true,
      notificarPagoFallido: map['notificar_pago_fallido'] ?? true,
      permitirTarjeta: map['permitir_tarjeta'] ?? true,
      permitirOxxo: map['permitir_oxxo'] ?? false,
      permitirSpei: map['permitir_spei'] ?? true,
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'negocio_id': negocioId,
    'stripe_account_id': stripeAccountId,
    'stripe_public_key': stripePublicKey,
    'stripe_secret_key': stripeSecretKey,
    'webhook_secret': webhookSecret,
    'modo_produccion': modoProduccion,
    'activo': activo,
    'link_pago_habilitado': linkPagoHabilitado,
    'domiciliacion_habilitada': domiciliacionHabilitada,
    'oxxo_habilitado': oxxoHabilitado,
    'spei_habilitado': speiHabilitado,
    'comision_manejo': comisionManejo,
    'cobrar_comision_cliente': cobrarComisionCliente,
    'porcentaje_comision': porcentajeComision,
    'notificar_pago_exitoso': notificarPagoExitoso,
    'notificar_pago_fallido': notificarPagoFallido,
    'permitir_tarjeta': permitirTarjeta,
    'permitir_oxxo': permitirOxxo,
    'permitir_spei': permitirSpei,
  };

  Map<String, dynamic> toMapForInsert() {
    final map = toMap();
    map.remove('id');
    return map;
  }
}

/// Modelo para Links de Pago (enviar por WhatsApp)
class LinkPagoModel {
  final String id;
  final String negocioId;
  final String clienteId;
  final String? prestamoId;
  final String? tandaId;
  final String? amortizacionId;
  final String concepto;
  final double monto;
  final String? stripePaymentLinkId;
  final String? stripeUrl;
  final String? urlCorta;
  final String estado; // pendiente, pagado, expirado, cancelado
  final DateTime? fechaExpiracion;
  final DateTime? fechaPago;
  final bool enviadoPorWhatsapp;
  final DateTime? fechaEnvioWhatsapp;
  final String? creadoPor;
  final DateTime createdAt;

  LinkPagoModel({
    required this.id,
    required this.negocioId,
    required this.clienteId,
    this.prestamoId,
    this.tandaId,
    this.amortizacionId,
    required this.concepto,
    required this.monto,
    this.stripePaymentLinkId,
    this.stripeUrl,
    this.urlCorta,
    this.estado = 'pendiente',
    this.fechaExpiracion,
    this.fechaPago,
    this.enviadoPorWhatsapp = false,
    this.fechaEnvioWhatsapp,
    this.creadoPor,
    required this.createdAt,
  });

  factory LinkPagoModel.fromMap(Map<String, dynamic> map) {
    return LinkPagoModel(
      id: map['id'] ?? '',
      negocioId: map['negocio_id'] ?? '',
      clienteId: map['cliente_id'] ?? '',
      prestamoId: map['prestamo_id'],
      tandaId: map['tanda_id'],
      amortizacionId: map['amortizacion_id'],
      concepto: map['concepto'] ?? '',
      monto: (map['monto'] as num?)?.toDouble() ?? 0,
      stripePaymentLinkId: map['stripe_payment_link_id'],
      stripeUrl: map['stripe_url'],
      urlCorta: map['url_corta'] ?? map['url'],
      estado: map['estado'] ?? 'pendiente',
      fechaExpiracion: map['fecha_expiracion'] != null 
          ? DateTime.parse(map['fecha_expiracion']) 
          : null,
      fechaPago: map['fecha_pago'] != null 
          ? DateTime.parse(map['fecha_pago']) 
          : null,
      enviadoPorWhatsapp: map['enviado_por_whatsapp'] ?? false,
      fechaEnvioWhatsapp: map['fecha_envio_whatsapp'] != null 
          ? DateTime.parse(map['fecha_envio_whatsapp']) 
          : null,
      creadoPor: map['creado_por'],
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toMapForInsert() => {
    'negocio_id': negocioId,
    'cliente_id': clienteId,
    'prestamo_id': prestamoId,
    'tanda_id': tandaId,
    'amortizacion_id': amortizacionId,
    'concepto': concepto,
    'monto': monto,
    'stripe_payment_link_id': stripePaymentLinkId,
    'url_corta': urlCorta,
    'estado': estado,
    'fecha_expiracion': fechaExpiracion?.toIso8601String(),
    'creado_por': creadoPor,
  };

  bool get estaPendiente => estado == 'pendiente';
  bool get estaPagado => estado == 'pagado';
  bool get estaExpirado => estado == 'expirado';

  /// URL disponible para enviar al cliente (Stripe o URL corta)
  String? get url => urlCorta ?? stripeUrl;
}

/// Enum para métodos de pago
enum MetodoPago {
  efectivo,
  transferencia,
  tarjetaStripe,
  linkPago,
  domiciliacion,
  oxxo,
  spei,
}

extension MetodoPagoExtension on MetodoPago {
  String get valor {
    switch (this) {
      case MetodoPago.efectivo: return 'efectivo';
      case MetodoPago.transferencia: return 'transferencia';
      case MetodoPago.tarjetaStripe: return 'tarjeta_stripe';
      case MetodoPago.linkPago: return 'link_pago';
      case MetodoPago.domiciliacion: return 'domiciliacion';
      case MetodoPago.oxxo: return 'oxxo';
      case MetodoPago.spei: return 'spei';
    }
  }

  String get etiqueta {
    switch (this) {
      case MetodoPago.efectivo: return '💵 Efectivo';
      case MetodoPago.transferencia: return '🏦 Transferencia';
      case MetodoPago.tarjetaStripe: return '💳 Tarjeta';
      case MetodoPago.linkPago: return '🔗 Link de Pago';
      case MetodoPago.domiciliacion: return '🔄 Domiciliación';
      case MetodoPago.oxxo: return '🏪 OXXO';
      case MetodoPago.spei: return '⚡ SPEI';
    }
  }

  // Alias para compatibilidad
  String get label => etiqueta;

  bool get esStripe {
    return this == MetodoPago.tarjetaStripe || 
           this == MetodoPago.linkPago || 
           this == MetodoPago.domiciliacion ||
           this == MetodoPago.oxxo ||
           this == MetodoPago.spei;
  }

  bool get esEfectivo {
    return this == MetodoPago.efectivo || this == MetodoPago.transferencia;
  }

  static MetodoPago fromString(String value) {
    switch (value.toLowerCase()) {
      case 'efectivo': return MetodoPago.efectivo;
      case 'transferencia': return MetodoPago.transferencia;
      case 'tarjeta_stripe': return MetodoPago.tarjetaStripe;
      case 'link_pago': return MetodoPago.linkPago;
      case 'domiciliacion': return MetodoPago.domiciliacion;
      case 'oxxo': return MetodoPago.oxxo;
      case 'spei': return MetodoPago.spei;
      default: return MetodoPago.efectivo;
    }
  }
}
