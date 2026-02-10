/// ═══════════════════════════════════════════════════════════════════════════════
/// MODELO QR COBRO - Robert Darin Fintech V10.7
/// ═══════════════════════════════════════════════════════════════════════════════
/// Sistema de verificación de cobros en efectivo con código QR
/// - Doble confirmación (cobrador + cliente)
/// - Geolocalización
/// - Prevención de fraudes
/// ═══════════════════════════════════════════════════════════════════════════════

class QrCobroModel {
  final String id;
  final String negocioId;
  final String codigoQr;
  final String? codigoVerificacion;
  final String? cobradorId;
  final String clienteId;
  final String tipoCobro; // prestamo, tanda, purificadora, nice, ventas, climas
  final String referenciaId;
  final String? referenciaTabla;
  final double monto;
  final String concepto;
  final String? descripcionAdicional;
  final String estado; // pendiente, confirmado, expirado, cancelado, rechazado
  final DateTime? fechaExpiracion;
  
  // Confirmación del cobrador
  final bool cobradorConfirmo;
  final DateTime? cobradorConfirmoAt;
  final double? cobradorLatitud;
  final double? cobradorLongitud;
  final String? cobradorDireccion;
  
  // Confirmación del cliente
  final bool clienteConfirmo;
  final DateTime? clienteConfirmoAt;
  final double? clienteLatitud;
  final double? clienteLongitud;
  final String? clienteDispositivo;
  
  // Evidencia
  final String? fotoComprobanteUrl;
  final String? fotoSelfieUrl;
  final String? firmaDigitalCliente;
  
  // Resultado
  final bool pagoRegistrado;
  final String? pagoId;
  
  final DateTime createdAt;
  final DateTime? updatedAt;
  
  // Datos relacionados (para UI)
  final String? clienteNombre;
  final String? clienteTelefono;
  final String? cobradorNombre;
  final String? negocioNombre;

  QrCobroModel({
    required this.id,
    required this.negocioId,
    required this.codigoQr,
    this.codigoVerificacion,
    this.cobradorId,
    required this.clienteId,
    required this.tipoCobro,
    required this.referenciaId,
    this.referenciaTabla,
    required this.monto,
    required this.concepto,
    this.descripcionAdicional,
    this.estado = 'pendiente',
    this.fechaExpiracion,
    this.cobradorConfirmo = false,
    this.cobradorConfirmoAt,
    this.cobradorLatitud,
    this.cobradorLongitud,
    this.cobradorDireccion,
    this.clienteConfirmo = false,
    this.clienteConfirmoAt,
    this.clienteLatitud,
    this.clienteLongitud,
    this.clienteDispositivo,
    this.fotoComprobanteUrl,
    this.fotoSelfieUrl,
    this.firmaDigitalCliente,
    this.pagoRegistrado = false,
    this.pagoId,
    required this.createdAt,
    this.updatedAt,
    this.clienteNombre,
    this.clienteTelefono,
    this.cobradorNombre,
    this.negocioNombre,
  });

  factory QrCobroModel.fromMap(Map<String, dynamic> map) {
    return QrCobroModel(
      id: map['id'] ?? '',
      negocioId: map['negocio_id'] ?? '',
      codigoQr: map['codigo_qr'] ?? '',
      codigoVerificacion: map['codigo_verificacion'],
      cobradorId: map['cobrador_id'],
      clienteId: map['cliente_id'] ?? '',
      tipoCobro: map['tipo_cobro'] ?? 'otro',
      referenciaId: map['referencia_id'] ?? '',
      referenciaTabla: map['referencia_tabla'],
      monto: (map['monto'] as num?)?.toDouble() ?? 0,
      concepto: map['concepto'] ?? '',
      descripcionAdicional: map['descripcion_adicional'],
      estado: map['estado'] ?? 'pendiente',
      fechaExpiracion: map['fecha_expiracion'] != null 
          ? DateTime.tryParse(map['fecha_expiracion']) 
          : null,
      cobradorConfirmo: map['cobrador_confirmo'] ?? false,
      cobradorConfirmoAt: map['cobrador_confirmo_at'] != null 
          ? DateTime.tryParse(map['cobrador_confirmo_at']) 
          : null,
      cobradorLatitud: (map['cobrador_latitud'] as num?)?.toDouble(),
      cobradorLongitud: (map['cobrador_longitud'] as num?)?.toDouble(),
      cobradorDireccion: map['cobrador_direccion'],
      clienteConfirmo: map['cliente_confirmo'] ?? false,
      clienteConfirmoAt: map['cliente_confirmo_at'] != null 
          ? DateTime.tryParse(map['cliente_confirmo_at']) 
          : null,
      clienteLatitud: (map['cliente_latitud'] as num?)?.toDouble(),
      clienteLongitud: (map['cliente_longitud'] as num?)?.toDouble(),
      clienteDispositivo: map['cliente_dispositivo'],
      fotoComprobanteUrl: map['foto_comprobante_url'],
      fotoSelfieUrl: map['foto_selfie_url'],
      firmaDigitalCliente: map['firma_digital_cliente'],
      pagoRegistrado: map['pago_registrado'] ?? false,
      pagoId: map['pago_id'],
      createdAt: DateTime.tryParse(map['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: map['updated_at'] != null 
          ? DateTime.tryParse(map['updated_at']) 
          : null,
      // Datos de joins
      clienteNombre: map['cliente_nombre'] ?? map['clientes']?['nombre'],
      clienteTelefono: map['cliente_telefono'] ?? map['clientes']?['telefono'],
      cobradorNombre: map['cobrador_nombre'] ?? map['usuarios']?['nombre_completo'],
      negocioNombre: map['negocio_nombre'] ?? map['negocios']?['nombre'],
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'negocio_id': negocioId,
    'codigo_qr': codigoQr,
    'codigo_verificacion': codigoVerificacion,
    'cobrador_id': cobradorId,
    'cliente_id': clienteId,
    'tipo_cobro': tipoCobro,
    'referencia_id': referenciaId,
    'referencia_tabla': referenciaTabla,
    'monto': monto,
    'concepto': concepto,
    'descripcion_adicional': descripcionAdicional,
    'estado': estado,
    'fecha_expiracion': fechaExpiracion?.toIso8601String(),
    'cobrador_confirmo': cobradorConfirmo,
    'cobrador_confirmo_at': cobradorConfirmoAt?.toIso8601String(),
    'cobrador_latitud': cobradorLatitud,
    'cobrador_longitud': cobradorLongitud,
    'cobrador_direccion': cobradorDireccion,
    'cliente_confirmo': clienteConfirmo,
    'cliente_confirmo_at': clienteConfirmoAt?.toIso8601String(),
    'cliente_latitud': clienteLatitud,
    'cliente_longitud': clienteLongitud,
    'cliente_dispositivo': clienteDispositivo,
    'foto_comprobante_url': fotoComprobanteUrl,
    'foto_selfie_url': fotoSelfieUrl,
    'firma_digital_cliente': firmaDigitalCliente,
    'pago_registrado': pagoRegistrado,
    'pago_id': pagoId,
  };

  Map<String, dynamic> toMapForInsert() => {
    'negocio_id': negocioId,
    'codigo_qr': codigoQr,
    'codigo_verificacion': codigoVerificacion,
    'cobrador_id': cobradorId,
    'cliente_id': clienteId,
    'tipo_cobro': tipoCobro,
    'referencia_id': referenciaId,
    'referencia_tabla': referenciaTabla,
    'monto': monto,
    'concepto': concepto,
    'descripcion_adicional': descripcionAdicional,
    'fecha_expiracion': fechaExpiracion?.toIso8601String(),
  };

  // Helpers
  bool get estaExpirado => 
      fechaExpiracion != null && fechaExpiracion!.isBefore(DateTime.now());
  
  bool get estaConfirmado => estado == 'confirmado';
  
  bool get estaPendiente => estado == 'pendiente' && !estaExpirado;
  
  bool get ambosConfirmaron => cobradorConfirmo && clienteConfirmo;
  
  String get estadoDetallado {
    if (estaExpirado) return 'Expirado';
    if (ambosConfirmaron) return 'Completado';
    if (cobradorConfirmo && !clienteConfirmo) return 'Esperando cliente';
    if (!cobradorConfirmo && clienteConfirmo) return 'Esperando cobrador';
    return 'Pendiente';
  }
  
  String get tipoCobroDisplay {
    switch (tipoCobro) {
      case 'prestamo': return 'Préstamo';
      case 'tanda': return 'Tanda';
      case 'purificadora': return 'Purificadora';
      case 'nice': return 'Nice';
      case 'ventas': return 'Ventas';
      case 'climas': return 'Climas';
      default: return 'Otro';
    }
  }
}

/// Configuración del sistema QR por negocio
class QrCobrosConfigModel {
  final String id;
  final String negocioId;
  final int qrExpiraHoras;
  final int codigoExpiraMinutos;
  final bool requiereConfirmacionCliente;
  final bool requiereGps;
  final bool requiereFotoComprobante;
  final bool requiereFirmaDigital;
  final int distanciaMaximaMetros;
  final bool notificarAdminInmediato;
  final bool notificarClienteRecordatorio;
  final double montoMinimoQr;
  final double montoMaximoSinFoto;
  final String horaInicioCobros;
  final String horaFinCobros;
  final bool permitirFinesSemana;

  QrCobrosConfigModel({
    required this.id,
    required this.negocioId,
    this.qrExpiraHoras = 24,
    this.codigoExpiraMinutos = 30,
    this.requiereConfirmacionCliente = true,
    this.requiereGps = true,
    this.requiereFotoComprobante = false,
    this.requiereFirmaDigital = false,
    this.distanciaMaximaMetros = 500,
    this.notificarAdminInmediato = true,
    this.notificarClienteRecordatorio = true,
    this.montoMinimoQr = 0,
    this.montoMaximoSinFoto = 5000,
    this.horaInicioCobros = '07:00',
    this.horaFinCobros = '21:00',
    this.permitirFinesSemana = true,
  });

  factory QrCobrosConfigModel.fromMap(Map<String, dynamic> map) {
    return QrCobrosConfigModel(
      id: map['id'] ?? '',
      negocioId: map['negocio_id'] ?? '',
      qrExpiraHoras: map['qr_expira_horas'] ?? 24,
      codigoExpiraMinutos: map['codigo_expira_minutos'] ?? 30,
      requiereConfirmacionCliente: map['requiere_confirmacion_cliente'] ?? true,
      requiereGps: map['requiere_gps'] ?? true,
      requiereFotoComprobante: map['requiere_foto_comprobante'] ?? false,
      requiereFirmaDigital: map['requiere_firma_digital'] ?? false,
      distanciaMaximaMetros: map['distancia_maxima_metros'] ?? 500,
      notificarAdminInmediato: map['notificar_admin_inmediato'] ?? true,
      notificarClienteRecordatorio: map['notificar_cliente_recordatorio'] ?? true,
      montoMinimoQr: (map['monto_minimo_qr'] as num?)?.toDouble() ?? 0,
      montoMaximoSinFoto: (map['monto_maximo_sin_foto'] as num?)?.toDouble() ?? 5000,
      horaInicioCobros: map['hora_inicio_cobros'] ?? '07:00',
      horaFinCobros: map['hora_fin_cobros'] ?? '21:00',
      permitirFinesSemana: map['permitir_fines_semana'] ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
    'negocio_id': negocioId,
    'qr_expira_horas': qrExpiraHoras,
    'codigo_expira_minutos': codigoExpiraMinutos,
    'requiere_confirmacion_cliente': requiereConfirmacionCliente,
    'requiere_gps': requiereGps,
    'requiere_foto_comprobante': requiereFotoComprobante,
    'requiere_firma_digital': requiereFirmaDigital,
    'distancia_maxima_metros': distanciaMaximaMetros,
    'notificar_admin_inmediato': notificarAdminInmediato,
    'notificar_cliente_recordatorio': notificarClienteRecordatorio,
    'monto_minimo_qr': montoMinimoQr,
    'monto_maximo_sin_foto': montoMaximoSinFoto,
    'hora_inicio_cobros': horaInicioCobros,
    'hora_fin_cobros': horaFinCobros,
    'permitir_fines_semana': permitirFinesSemana,
  };
}
